#!/bin/bash

# リポジトリ情報の取得
GIT_REPO_OWNER=$(echo "$GITHUB_URL" | sed -E 's|https?://github.com/([^/]+)/.*|\1|')
GIT_REPO_NAME=$(echo "$GITHUB_URL" | sed -E 's|https?://github.com/[^/]+/([^/]+)(\.git)?|\1|')

# 認証情報
GITHUB_TOKEN="${GITHUB_CRED_PSW}"

export GIT_REPO_OWNER GIT_REPO_NAME GITHUB_TOKEN

# PR判定関数
is_change_request() {
    test -n "${CHANGE_ID:-}"
}

# PRコメント投稿関数
post_review_comment() {
    local repo_owner="$1"
    local repo_name="$2"
    local pr_number="$3"
    local comment_file="$4"
    
    echo "=== post_review_comment DEBUG ===" >&2
    echo "Repository Owner: $repo_owner" >&2
    echo "Repository Name: $repo_name" >&2
    echo "PR Number: $pr_number" >&2
    echo "Comment File: $comment_file" >&2
    echo "=================================" >&2
    
    # 引数チェック
    if [ -z "$repo_owner" ] || [ -z "$repo_name" ] || [ -z "$pr_number" ] || [ -z "$comment_file" ]; then
        echo "Error: Missing required arguments" >&2
        return 1
    fi
    
    # ファイル存在チェック
    if [ ! -f "$comment_file" ]; then
        echo "Error: Comment file not found: $comment_file" >&2
        return 1
    fi
    
    # 空ファイルチェック
    if [ ! -s "$comment_file" ]; then
        echo "Warning: Comment file is empty" >&2
        return 0
    fi
    
    # コメント内容のプレビュー
    echo "=== Comment Content (first 200 chars) ===" >&2
    head -c 200 "$comment_file" >&2
    echo "" >&2
    echo "==========================================" >&2
    
    local api_url="https://api.github.com/repos/${repo_owner}/${repo_name}/issues/${pr_number}/comments"
    echo "API URL: $api_url" >&2
    
    # Python3を優先的に使用（文字エンコーディング処理が確実）
    local payload
    if command -v python3 &> /dev/null; then
        echo "Using python3 for JSON encoding (UTF-8 safe)" >&2
        
        payload=$(python3 << 'PYTHON_SCRIPT'
import json
import sys
import os

comment_file = sys.argv[1]

try:
    # まずUTF-8で読み込みを試行
    try:
        with open(comment_file, 'r', encoding='utf-8') as f:
            body = f.read()
    except UnicodeDecodeError:
        # UTF-8で失敗した場合、CP932で読み込み
        with open(comment_file, 'r', encoding='cp932') as f:
            body = f.read()
    
    # JSON生成（ensure_ascii=Falseで日本語をそのまま出力）
    payload = json.dumps({'body': body}, ensure_ascii=False, indent=2)
    print(payload)
    
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
PYTHON_SCRIPT
 "$comment_file")
        
        if [ $? -ne 0 ]; then
            echo "Error: Failed to create JSON payload with python3" >&2
            return 1
        fi
        
    elif command -v jq &> /dev/null; then
        echo "Using jq for JSON encoding" >&2
        
        # iconv で UTF-8 に変換してから jq に渡す
        local utf8_file="${comment_file}.utf8"
        if command -v iconv &> /dev/null; then
            echo "Converting to UTF-8 with iconv..." >&2
            iconv -f CP932 -t UTF-8 "$comment_file" > "$utf8_file" 2>/dev/null || cp "$comment_file" "$utf8_file"
        else
            cp "$comment_file" "$utf8_file"
        fi
        
        payload=$(jq -n --rawfile body "$utf8_file" '{body: $body}')
        rm -f "$utf8_file"
        
        if [ $? -ne 0 ]; then
            echo "Error: Failed to create JSON payload with jq" >&2
            return 1
        fi
    else
        echo "Error: No JSON encoder found (python3 or jq required)" >&2
        return 1
    fi
    
    # デバッグ: 生成されたペイロードの確認
    echo "=== Generated Payload (first 300 chars) ===" >&2
    echo "$payload" | head -c 300 >&2
    echo "" >&2
    echo "============================================" >&2
    
    # 一時ファイルに保存してバイナリ送信
    local payload_file=$(mktemp)
    echo "$payload" > "$payload_file"
    
    # GitHub APIへリクエスト送信（ファイルから直接送信）
    local response
    response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Authorization: token ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Content-Type: application/json; charset=utf-8" \
        "$api_url" \
        --data-binary "@${payload_file}")
    
    # 一時ファイル削除
    rm -f "$payload_file"
    
    # HTTPステータスコード取得
    local http_code
    http_code=$(echo "$response" | tail -n1)
    local response_body
    response_body=$(echo "$response" | sed '$d')
    
    echo "" >&2
    echo "===============================" >&2
    echo "HTTP Status Code: $http_code" >&2
    
    # 成功判定
    if [ "$http_code" = "201" ]; then
        echo "✓ Comment posted successfully to PR #${pr_number}" >&2
        if command -v jq &> /dev/null; then
            local comment_url
            comment_url=$(echo "$response_body" | jq -r '.html_url // empty')
            if [ -n "$comment_url" ]; then
                echo "Comment URL: $comment_url" >&2
            fi
        fi
        return 0
    else
        echo "✗ Failed to post comment. HTTP status: $http_code" >&2
        echo "Response: $response_body" >&2
        
        # デバッグ情報
        echo "" >&2
        echo "=== Debug Info ===" >&2
        echo "Payload that was sent:" >&2
        echo "$payload" | head -n 20 >&2
        echo "Payload size: $(echo "$payload" | wc -c) bytes" >&2
        echo "==================" >&2
        
        return 1
    fi
}

# ベースコミット取得関数
get_base_commit() {
    if is_change_request; then
        # PRの場合、ターゲットブランチのHEADを取得
        git rev-parse "origin/${CHANGE_TARGET}"
    else
        # PRでない場合、前回のコミットを返す
        echo "${GIT_PREVIOUS_COMMIT:-}"
    fi
}

# 変更ファイル取得関数
get_changed_files() {
    if is_change_request; then
        local base_commit
        base_commit=$(git merge-base HEAD "origin/${CHANGE_TARGET}")
        git diff --name-only "$base_commit" HEAD
    else
        git diff --name-only HEAD^ HEAD
    fi
}

if [ "${DEBUG:-}" = "true" ]; then
    echo "=== github-jenkins.sh Loaded ==="
    echo "GIT_REPO_OWNER: ${GIT_REPO_OWNER}"
    echo "GIT_REPO_NAME: ${GIT_REPO_NAME}"
    echo "GITHUB_TOKEN: ${GITHUB_TOKEN:0:8}... (masked)"
    echo "================================="
fi

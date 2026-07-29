
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

# PRコメント投稿関数（4つの引数を受け取る）
post_review_comment() {
    local repo_owner="$1"
    local repo_name="$2"
    local pr_number="$3"
    local comment_file="$4"
    
    # デバッグ出力
    echo "=== post_review_comment DEBUG ==="
    echo "Repository Owner: $repo_owner"
    echo "Repository Name: $repo_name"
    echo "PR Number: $pr_number"
    echo "Comment File: $comment_file"
    echo "================================="
    
    # 引数チェック
    if [ -z "$repo_owner" ] || [ -z "$repo_name" ] || [ -z "$pr_number" ] || [ -z "$comment_file" ]; then
        echo "Error: Missing required arguments"
        echo "Usage: post_review_comment <repo_owner> <repo_name> <pr_number> <comment_file>"
        return 1
    fi
    
    # ファイル存在チェック
    if [ ! -f "$comment_file" ]; then
        echo "Error: Comment file not found: $comment_file"
        echo "Current directory: $(pwd)"
        echo "Absolute path: $(realpath "$comment_file" 2>/dev/null || echo "N/A")"
        ls -la "$(dirname "$comment_file")" 2>/dev/null || echo "Directory not found"
        return 1
    fi
    
    # ファイルが空かチェック
    if [ ! -s "$comment_file" ]; then
        echo "Warning: Comment file is empty: $comment_file"
        echo "Skipping comment posting."
        return 0
    fi
    
    # コメント内容を読み込み
    local comment_body
    comment_body=$(cat "$comment_file")
    
    echo "=== Comment Content (first 200 chars) ==="
    echo "$comment_body" | head -c 200
    echo ""
    echo "=========================================="
    
    # GitHub API エンドポイント
    local api_url="https://api.github.com/repos/${repo_owner}/${repo_name}/issues/${pr_number}/comments"
    
    echo "API URL: $api_url"
    
    # JSON エスケープ
    local json_body
    
    # jq がある場合
    if command -v jq &> /dev/null; then
        echo "Using jq for JSON encoding"
        json_body=$(echo "$comment_body" | jq -Rs .)
    # Python3 がある場合
    elif command -v python3 &> /dev/null; then
        echo "Using python3 for JSON encoding"
        json_body=$(python3 -c "import json, sys; print(json.dumps(sys.stdin.read()))" <<< "$comment_body")
    # Python がある場合
    elif command -v python &> /dev/null; then
        echo "Using python for JSON encoding"
        json_body=$(python -c "import json, sys; print(json.dumps(sys.stdin.read()))" <<< "$comment_body")
    else
        echo "Error: No JSON encoder found (jq, python3, or python)"
        echo "Please install jq or ensure Python is available"
        return 1
    fi
    
    # デバッグ: エスケープ後のJSON確認
    echo "=== Escaped JSON (first 300 chars) ==="
    echo "$json_body" | head -c 300
    echo ""
    echo "======================================="
    
    # GitHub API を使ってPRにコメントを投稿
    local response
    response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Authorization: token ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Content-Type: application/json" \
        "$api_url" \
        -d "{\"body\":${json_body}}")
    
    local http_code
    http_code=$(echo "$response" | tail -n1)
    local response_body
    response_body=$(echo "$response" | sed '$d')
    
    echo "HTTP Status Code: $http_code"
    
    if [ "$http_code" = "201" ]; then
        echo "✓ Comment posted successfully to PR #${pr_number}"
        
        # レスポンスからコメントURLを抽出
        if command -v jq &> /dev/null; then
            echo "Comment URL: $(echo "$response_body" | jq -r '.html_url')"
        else
            echo "Response: $response_body"
        fi
        return 0
    else
        echo "✗ Failed to post comment. HTTP status: $http_code"
        echo "Response: $response_body"
        
        # デバッグ情報
        echo ""
        echo "=== Debug Info ==="
        echo "Request body that was sent:"
        echo "{\"body\":${json_body}}"
        echo "=================="
        
        return 1
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

# デバッグ情報
if [ "${DEBUG:-}" = "true" ]; then
    echo "=== github-jenkins.sh Loaded ==="
    echo "GIT_REPO_OWNER: ${GIT_REPO_OWNER}"
    echo "GIT_REPO_NAME: ${GIT_REPO_NAME}"
    echo "GITHUB_TOKEN: ${GITHUB_TOKEN:0:8}... (masked)"
    echo "CHANGE_ID: ${CHANGE_ID:-not set}"
    echo "CHANGE_TARGET: ${CHANGE_TARGET:-not set}"
    echo "is_change_request: $(is_change_request && echo 'true' || echo 'false')"
    
    # 利用可能なJSONエンコーダーを確認
    echo "Available JSON encoders:"
    command -v jq &> /dev/null && echo "  ✓ jq" || echo "  ✗ jq"
    command -v python3 &> /dev/null && echo "  ✓ python3" || echo "  ✗ python3"
    command -v python &> /dev/null && echo "  ✓ python" || echo "  ✗ python"
    echo "================================="
fi

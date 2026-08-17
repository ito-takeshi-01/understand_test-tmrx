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
    
    echo "=== post_review_comment DEBUG ==="
    echo "Repository Owner: $repo_owner"
    echo "Repository Name: $repo_name"
    echo "PR Number: $pr_number"
    echo "Comment File: $comment_file"
    echo "================================="
    
    if [ -z "$repo_owner" ] || [ -z "$repo_name" ] || [ -z "$pr_number" ] || [ -z "$comment_file" ]; then
        echo "Error: Missing required arguments"
        return 1
    fi
    
    if [ ! -f "$comment_file" ]; then
        echo "Error: Comment file not found: $comment_file"
        return 1
    fi
    
    if [ ! -s "$comment_file" ]; then
        echo "Warning: Comment file is empty"
        return 0
    fi
    
    local comment_body
    comment_body=$(cat "$comment_file")
    
    echo "=== Comment Content (first 200 chars) ==="
    echo "$comment_body" | head -c 200
    echo ""
    echo "=========================================="
    
    local api_url="https://api.github.com/repos/${repo_owner}/${repo_name}/issues/${pr_number}/comments"
    echo "API URL: $api_url"
    
    local json_body
    if command -v jq &> /dev/null; then
        echo "Using jq for JSON encoding"
        json_body=$(echo "$comment_body" | jq -Rs .)
    elif command -v python3 &> /dev/null; then
        echo "Using python3 for JSON encoding"
        json_body=$(python3 -c "import json, sys; print(json.dumps(sys.stdin.read()))" <<< "$comment_body")
    elif command -v python &> /dev/null; then
        echo "Using python for JSON encoding"
        json_body=$(python -c "import json, sys; print(json.dumps(sys.stdin.read()))" <<< "$comment_body")
    else
        echo "Error: No JSON encoder found"
        return 1
    fi
    
    echo "=== Escaped JSON (first 300 chars) ==="
    echo "$json_body" | head -c 300
    echo ""
    echo "======================================="
    
    local response
    response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Authorization: token ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Content-Type: application/json" \
        "$api_url" \
        -d "{\"body\":$json_body}")
    
    local http_code
    http_code=$(echo "$response" | tail -n1)
    local response_body
    response_body=$(echo "$response" | sed '$d')
    
    echo "HTTP Status Code: $http_code"
    
    if [ "$http_code" = "201" ]; then
        echo "Comment posted successfully to PR #${pr_number}"
        if command -v jq &> /dev/null; then
            echo "Comment URL: $(echo "$response_body" | jq -r '.html_url')"
        fi
        return 0
    else
        echo "Failed to post comment. HTTP status: $http_code"
        echo "Response: $response_body"
        echo ""
        echo "=== Debug Info ==="
        echo "Request body that was sent:"
        echo "{\"body\":$json_body}"
        echo "=================="
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

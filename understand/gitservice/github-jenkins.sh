#!/bin/bash

# ===============================
# リポジトリ情報の取得
# ===============================
GIT_REPO_OWNER=$(echo "$GITHUB_URL" | sed -E 's|https?://github.com/([^/]+)/.*|\1|')
GIT_REPO_NAME=$(echo "$GITHUB_URL" | sed -E 's|https?://github.com/[^/]+/([^/]+)(\.git)?|\1|')

# ===============================
# 認証情報の設定
# ===============================
# Jenkins credentials から取得
GITHUB_TOKEN="${GITHUB_CRED_PSW}"

# export して他のスクリプトから参照可能にする
export GIT_REPO_OWNER GIT_REPO_NAME GITHUB_TOKEN

# ===============================
# PR判定関数
# ===============================
is_change_request() {
    # Jenkins の CHANGE_ID が設定されていればPRビルド
    test -n "${CHANGE_ID:-}"
}

# ===============================
# PRコメント投稿関数
# ===============================
post_review_comment() {
    local comment_file="$1"
    
    if [ ! -f "$comment_file" ]; then
        echo "Error: Comment file not found: $comment_file"
        return 1
    fi
    
    local comment_body
    comment_body=$(cat "$comment_file")
    
    # GitHub API を使ってPRにコメントを投稿
    curl -X POST \
        -H "Authorization: token ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/${GIT_REPO_OWNER}/${GIT_REPO_NAME}/issues/${CHANGE_ID}/comments" \
        -d "{\"body\":$(echo "$comment_body" | jq -Rs .)}"
    
    if [ $? -eq 0 ]; then
        echo "Comment posted successfully to PR #${CHANGE_ID}"
    else
        echo "Failed to post comment to PR #${CHANGE_ID}"
        return 1
    fi
}

# ===============================
# 変更ファイル取得関数
# ===============================
get_changed_files() {
    if is_change_request; then
        # PRの場合: ベースブランチとの差分
        local base_commit
        base_commit=$(git merge-base HEAD "origin/${CHANGE_TARGET}")
        git diff --name-only "$base_commit" HEAD
    else
        # mainブランチの場合: 前回のコミットとの差分
        git diff --name-only HEAD^ HEAD
    fi
}

# ===============================
# デバッグ情報出力
# ===============================
if [ "${DEBUG:-}" = "true" ]; then
    echo "=== github-jenkins.sh DEBUG ==="
    echo "GIT_REPO_OWNER: $GIT_REPO_OWNER"
    echo "GIT_REPO_NAME: $GIT_REPO_NAME"
    echo "GITHUB_TOKEN: [MASKED]"
    echo "CHANGE_ID: ${CHANGE_ID:-not set}"
    echo "CHANGE_TARGET: ${CHANGE_TARGET:-not set}"
    echo "is_change_request: $(is_change_request && echo 'true' || echo 'false')"
    echo "==============================="
fi
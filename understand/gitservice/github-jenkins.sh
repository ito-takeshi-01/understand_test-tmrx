#!/bin/sh

# GitHub Jenkins 環境用の設定

# リポジトリオーナーとリポジトリ名を取得
GIT_REPO_OWNER=$(echo "$GITHUB_URL" | sed -E 's|https?://github.com/([^/]+)/.*|\1|')
GIT_REPO_NAME=$(echo "$GITHUB_URL" | sed -E 's|https?://github.com/[^/]+/([^/]+)(\.git)?|\1|')

# 認証情報
GITHUB_TOKEN="$GITHUB_CRED_PSW"

export GIT_REPO_OWNER GIT_REPO_NAME GITHUB_TOKEN
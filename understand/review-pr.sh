#!/bin/sh -eux
# PRにレビューコメント

# デバッグ出力
echo "DEBUG: \$0 = $0"
echo "DEBUG: PWD = $(pwd)"
echo "DEBUG: GITSERVICE = ${GITSERVICE}"
echo "DEBUG: STORAGESERVICE = ${STORAGESERVICE}"

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "DEBUG: SCRIPT_DIR = ${SCRIPT_DIR}"

# 必要なスクリプトを読み込み
. "${SCRIPT_DIR}/gitservice/${GITSERVICE}.sh"
. "${SCRIPT_DIR}/storage/${STORAGESERVICE}.sh"
. "${SCRIPT_DIR}/variables"

# コメントファイル
review_comment_file=$1

# レビューコメントを投稿
post_review_comment "${GIT_REPO_OWNER}" "${GIT_REPO_NAME}" "${CHANGE_ID}" "${review_comment_file}"
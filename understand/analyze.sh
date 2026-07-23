#!/bin/sh -eux

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 外部スクリプトの読み込み
. "$SCRIPT_DIR/gitservice/$GITSERVICE.sh"
. "$SCRIPT_DIR/storage/$STORAGESERVICE.sh"
. "$SCRIPT_DIR/variables"

# 前回の解析データを取得
if get_analysis_data "$GIT_REPO_OWNER" "$GIT_REPO_NAME" "$PREV_COMMIT" "$PREV_UND_DB_ARCHIVE"
then
    tar xzf "$PREV_UND_DB_ARCHIVE"
    rm -rf "$PREV_UND_DB_ARCHIVE"
    rm -rf "$UND_DB_DIR"
    und create -db "$UND_DB_DIR" -gitcommit "$GIT_COMMIT" -refdb "$PREV_UND_DB_DIR"
    und settings -ComparisonProjectPath "$PREV_UND_DB_DIR" "$UND_DB_DIR"
else
    rm -rf "$UND_DB_DIR"
    und create -db "$UND_DB_DIR" -gitcommit "$GIT_COMMIT"
    mkdir -p "$UND_DB_DIR/local"
    und settings @"$SCRIPT_DIR/settings" -db "$UND_DB_DIR"
    und add @"$SCRIPT_DIR/files" -db "$UND_DB_DIR"
fi

# 解析を実行
und analyze "$UND_DB_DIR"
tar czf "$UND_DB_ARCHIVE" "$UND_DB_DIR"

# 解析データをアップロード
if [ "${1:-}" = '--upload' ]
then
    put_analysis_data "$GIT_REPO_OWNER" "$GIT_REPO_NAME" "$GIT_COMMIT" "$UND_DB_ARCHIVE"
fi
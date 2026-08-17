#!/bin/sh -eux

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 外部スクリプトの読み込み（variablesは後で読み込む）
. "$SCRIPT_DIR/gitservice/$GITSERVICE.sh"
. "$SCRIPT_DIR/storage/$STORAGESERVICE.sh"

# ベースコミットを取得（PRの場合はターゲットブランチのHEAD）
PREV_COMMIT=$(get_base_commit)

# デバッグ出力
echo "DEBUG: PREV_COMMIT = '$PREV_COMMIT'" >&2
echo "DEBUG: GIT_COMMIT = '$GIT_COMMIT'" >&2

# 変数ファイルを読み込み（PREV_COMMITが定義された後）
. "$SCRIPT_DIR/variables"

# デバッグ出力（variables読み込み後）
echo "DEBUG: PREV_UND_DB_ARCHIVE = '$PREV_UND_DB_ARCHIVE'" >&2
echo "DEBUG: UND_DB_ARCHIVE = '$UND_DB_ARCHIVE'" >&2

# 作業ディレクトリを保存
WORK_DIR="$(pwd)"

# Gitリポジトリのルートに移動
cd "$SCRIPT_DIR/.."

# 前回の解析データを取得
if get_analysis_data "$GIT_REPO_OWNER" "$GIT_REPO_NAME" "$PREV_COMMIT" "$PREV_UND_DB_ARCHIVE"
then
    tar xzf "$PREV_UND_DB_ARCHIVE" -C "$WORK_DIR"
    rm -rf "$PREV_UND_DB_ARCHIVE"
    rm -rf "$WORK_DIR/$UND_DB_DIR"
    und create -db "$WORK_DIR/$UND_DB_DIR" -gitcommit "$GIT_COMMIT" -refdb "$WORK_DIR/$PREV_UND_DB_DIR"
    und settings -ComparisonProjectPath "$WORK_DIR/$PREV_UND_DB_DIR" "$WORK_DIR/$UND_DB_DIR"
else
    rm -rf "$WORK_DIR/$UND_DB_DIR"
    und create -db "$WORK_DIR/$UND_DB_DIR" -gitcommit "$GIT_COMMIT"
    mkdir -p "$WORK_DIR/$UND_DB_DIR/local"
    und settings @"$SCRIPT_DIR/settings" -db "$WORK_DIR/$UND_DB_DIR"
    und add @"$SCRIPT_DIR/files" -db "$WORK_DIR/$UND_DB_DIR"
fi

# 解析を実行
und analyze "$WORK_DIR/$UND_DB_DIR"

# 元のディレクトリに戻る
cd "$WORK_DIR"

tar czf "$UND_DB_ARCHIVE" "$UND_DB_DIR"

# 解析データをアップロード
if [ "${{1:-}}" = '--upload' ]
then
    put_analysis_data "$GIT_REPO_OWNER" "$GIT_REPO_NAME" "$GIT_COMMIT" "$UND_DB_ARCHIVE"
fi
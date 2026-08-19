#!/bin/sh -eux

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 外部スクリプトの読み込み（variablesは後で読み込む）
. "$SCRIPT_DIR/gitservice/$GITSERVICE.sh"
. "$SCRIPT_DIR/storage/$STORAGESERVICE.sh"

# デバッグ: 利用可能なGit環境変数を表示
echo "DEBUG: GIT_COMMIT = '$GIT_COMMIT'" >&2
echo "DEBUG: GIT_PREVIOUS_COMMIT = '${GIT_PREVIOUS_COMMIT:-}'" >&2
echo "DEBUG: GIT_PREVIOUS_SUCCESSFUL_COMMIT = '${GIT_PREVIOUS_SUCCESSFUL_COMMIT:-}'" >&2
echo "DEBUG: CHANGE_ID = '${CHANGE_ID:-}'" >&2

# 比較対象のコミットを決定
if [ -n "${CHANGE_ID:-}" ]; then
    # PRビルドの場合
    echo "DEBUG: This is a PR build (CHANGE_ID=$CHANGE_ID)" >&2
    
    if [ -n "${GIT_PREVIOUS_SUCCESSFUL_COMMIT:-}" ]; then
        PREV_COMMIT="$GIT_PREVIOUS_SUCCESSFUL_COMMIT"
        echo "DEBUG: Using GIT_PREVIOUS_SUCCESSFUL_COMMIT for comparison" >&2
    elif [ -n "${GIT_PREVIOUS_COMMIT:-}" ]; then
        PREV_COMMIT="$GIT_PREVIOUS_COMMIT"
        echo "DEBUG: Using GIT_PREVIOUS_COMMIT for comparison" >&2
    else
        # どちらもない場合は、mainブランチとの比較
        PREV_COMMIT=$(get_base_commit)
        echo "DEBUG: Using base commit (main branch) for comparison" >&2
    fi
else
    # PR以外のビルド（mainブランチなど）
    echo "DEBUG: This is not a PR build" >&2
    
    if [ -n "${GIT_PREVIOUS_COMMIT:-}" ]; then
        PREV_COMMIT="$GIT_PREVIOUS_COMMIT"
        echo "DEBUG: Using GIT_PREVIOUS_COMMIT for comparison" >&2
    else
        PREV_COMMIT=$(get_base_commit)
        echo "DEBUG: Using base commit for comparison" >&2
    fi
fi

echo "DEBUG: PREV_COMMIT = '$PREV_COMMIT'" >&2

# 変数ファイルを読み込み（PREV_COMMITが定義された後）
. "$SCRIPT_DIR/variables"

# デバッグ出力（variables読み込み後）
echo "DEBUG: PREV_UND_DB_ARCHIVE = '$PREV_UND_DB_ARCHIVE'" >&2
echo "DEBUG: UND_DB_ARCHIVE = '$UND_DB_ARCHIVE'" >&2

# 前回の解析データを取得
if get_analysis_data "$GIT_REPO_OWNER" "$GIT_REPO_NAME" "$PREV_COMMIT" "$PREV_UND_DB_ARCHIVE"
then
    tar xzf "$PREV_UND_DB_ARCHIVE" -C "$SCRIPT_DIR"
    rm -rf "$PREV_UND_DB_ARCHIVE"
    rm -rf "$SCRIPT_DIR/$UND_DB_DIR"
    # 前回のDBをコピーして新しいDBを作成
    cp -r "$SCRIPT_DIR/$PREV_UND_DB_DIR" "$SCRIPT_DIR/$UND_DB_DIR"
    und settings -ComparisonProjectPath "$SCRIPT_DIR/$PREV_UND_DB_DIR" "$SCRIPT_DIR/$UND_DB_DIR"
else
    rm -rf "$SCRIPT_DIR/$UND_DB_DIR"
    und create -db "$SCRIPT_DIR/$UND_DB_DIR"
    mkdir -p "$SCRIPT_DIR/$UND_DB_DIR/local"
    und settings @"$SCRIPT_DIR/settings" -db "$SCRIPT_DIR/$UND_DB_DIR"
    und add @"$SCRIPT_DIR/files" -db "$SCRIPT_DIR/$UND_DB_DIR"
fi

# 解析を実行
und analyze "$SCRIPT_DIR/$UND_DB_DIR"

tar czf "$SCRIPT_DIR/$UND_DB_ARCHIVE" -C "$SCRIPT_DIR" "$UND_DB_DIR"

# 解析データをアップロード
if [ "${1:-}" = '--upload' ]
then
    put_analysis_data "$GIT_REPO_OWNER" "$GIT_REPO_NAME" "$GIT_COMMIT" "$SCRIPT_DIR/$UND_DB_ARCHIVE"
fi
#!/bin/sh -eux
# 変更された関数のグラフをPRにフィードバック

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/gitservice/$GITSERVICE.sh"
. "$SCRIPT_DIR/storage/$STORAGESERVICE.sh"

# デバッグ: 利用可能なGit環境変数を表示
echo "DEBUG: GIT_COMMIT = '$GIT_COMMIT'" >&2
echo "DEBUG: GIT_PREVIOUS_COMMIT = '${GIT_PREVIOUS_COMMIT:-}'" >&2
echo "DEBUG: GIT_PREVIOUS_SUCCESSFUL_COMMIT = '${GIT_PREVIOUS_SUCCESSFUL_COMMIT:-}'" >&2
echo "DEBUG: CHANGE_ID = '${CHANGE_ID:-}'" >&2

# 比較対象のコミットを決定（analyze.shと同じロジック）
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
        PREV_COMMIT=$(get_base_commit)
        echo "DEBUG: Using base commit (main branch) for comparison" >&2
    fi
else
    # PR以外のビルド
    echo "DEBUG: This is not a PR build" >&2
    
    if [ -n "${GIT_PREVIOUS_COMMIT:-}" ]; then
        PREV_COMMIT="$GIT_PREVIOUS_COMMIT"
        echo "DEBUG: Using GIT_PREVIOUS_COMMIT for comparison" >&2
    else
        PREV_COMMIT=$(get_base_commit)
        echo "DEBUG: Using base commit for comparison" >&2
    fi
fi

echo "DEBUG: PREV_COMMIT (final) = '$PREV_COMMIT'" >&2

# 変数ファイルを読み込み（PREV_COMMITが定義された後）
. "$SCRIPT_DIR/variables"

# デバッグ出力（variables読み込み後）
echo "DEBUG: PREV_UND_DB_DIR = '$PREV_UND_DB_DIR'" >&2
echo "DEBUG: UND_DB_DIR = '$UND_DB_DIR'" >&2

# PRに対する実行か否か
if ! is_change_request
then
    echo 'PRに対する実行ではありません。' 1>&2
    exit 1
fi

# ベースブランチの Understand データベースが存在しない場合は終了
if [ ! -d "$PREV_UND_DB_DIR" ]
then
    echo 'ベースブランチの Understand データベースが存在しないため、変更された関数の解析は実行されませんでした。'
    exit 0
fi

# 比較設定は analyze.sh で設定済み
echo "DEBUG: Using comparison DB: $PREV_UND_DB_DIR" >&2

# 作業用ファイル・ディレクトリ
functions_list_file=$(mktemp)
unique_names_list_file=$(mktemp)
images_dir=$(mktemp -d)
review_comment_table_file=$(mktemp)
review_comment_images_file=$(mktemp)

# スクリプト終了時のクリーンアップ
cleanup() {
    rm -rf "$functions_list_file" "$unique_names_list_file" "$images_dir" "$review_comment_table_file" "$review_comment_images_file"
}
trap cleanup EXIT

# 変更された関数のリストを作成
echo "DEBUG: Exporting changes..." >&2
echo "DEBUG: Command: und export -db \"$UND_DB_DIR\" -changes -columns \"PercentChanged,Long Name,File Name,Unique Name\" -kinds \"Function, Procedure, Subroutine, Method\" \"$functions_list_file\"" >&2

und export -db "$UND_DB_DIR" \
    -changes \
    -columns "PercentChanged,Long Name,File Name,Unique Name" \
    -kinds "Function, Procedure, Subroutine, Method" \
    "$functions_list_file" 2>&1 | tee /dev/stderr || true

echo "DEBUG: functions_list_file content:" >&2
cat "$functions_list_file" >&2
echo "DEBUG: Line count: $(wc -l < "$functions_list_file")" >&2

if [ $(wc --lines < "$functions_list_file") -eq 1 ]
then
    echo '変更された関数はありません。'
    exit 0
fi
sed -i '1d; s/"//g' "$functions_list_file"
sort --general-numeric-sort --reverse --output="$functions_list_file" "$functions_list_file"

# 変更された関数ごとに
cat "$functions_list_file" | while IFS=, read -r rank function_name file_name unique_name
do
    # _export_graphics_.pl に渡すエンティティ名
    echo "$unique_name" >> "$unique_names_list_file"
    # レビューコメントの表
    echo "| $function_name | $rank | $file_name |" >> "$review_comment_table_file"
    # レビューコメントの画像
    generate_pr_review_comment "$GIT_REPO_OWNER" "$GIT_REPO_NAME" "$GIT_COMMIT" "$function_name" "$(echo "$unique_name" | sed -e 's/[\.:\/\\\,\ @]/_/g')" "$file_name" >> "$review_comment_images_file"
done

# 変更された関数の画像を生成・アップロード
uperl "$SCRIPT_DIR/_export_graphics_.pl" \
    -db "$UND_DB_DIR" \
    -ents "$unique_names_list_file" \
    -format svg \
    -report "Control Flow" \
    -dir "$images_dir" \
    -options "Collapse=On;Comments=Off" \
    -variant "Compare" \
    1>&2
for image_file in "$images_dir"/*.svg
do
    if [ "$image_file" != "$images_dir/*.svg" ]
    then
        put_image_file "$GIT_REPO_OWNER" "$GIT_REPO_NAME" "$GIT_COMMIT" "$image_file"
    fi
done

# レビューコメントを出力
cat <<-HEADER
以下の関数が変更されました。

| 関数 | Percent Changed | ファイル |
| -------- | -------- | -------- |
HEADER
cat "$review_comment_table_file"
cat "$review_comment_images_file"
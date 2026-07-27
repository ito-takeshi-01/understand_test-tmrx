#!/bin/sh -eux
# 変更された関数のグラフをPRにフィードバック

# === デバッグ出力開始 ===
echo "=== DEBUG START ===" 1>&2
echo "DEBUG: \$0 = $0" 1>&2
echo "DEBUG: PWD = $(pwd)" 1>&2
echo "DEBUG: GITSERVICE = ${GITSERVICE}" 1>&2
echo "DEBUG: STORAGESERVICE = ${STORAGESERVICE}" 1>&2

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "DEBUG: SCRIPT_DIR = ${SCRIPT_DIR}" 1>&2

# ディレクトリ構造の確認
echo "DEBUG: Listing ${SCRIPT_DIR}:" 1>&2
ls -la "${SCRIPT_DIR}/" 1>&2 || true
echo "DEBUG: Listing ${SCRIPT_DIR}/gitservice/:" 1>&2
ls -la "${SCRIPT_DIR}/gitservice/" 1>&2 || true

# ファイルの存在確認
echo "DEBUG: Checking files existence:" 1>&2
test -f "${SCRIPT_DIR}/gitservice/${GITSERVICE}.sh" && echo "  ✓ gitservice/${GITSERVICE}.sh exists" 1>&2 || echo "  ✗ gitservice/${GITSERVICE}.sh NOT FOUND" 1>&2
test -f "${SCRIPT_DIR}/storage/${STORAGESERVICE}.sh" && echo "  ✓ storage/${STORAGESERVICE}.sh exists" 1>&2 || echo "  ✗ storage/${STORAGESERVICE}.sh NOT FOUND" 1>&2
test -f "${SCRIPT_DIR}/variables" && echo "  ✓ variables exists" 1>&2 || echo "  ✗ variables NOT FOUND" 1>&2
echo "=== DEBUG END ===" 1>&2

# 必要なスクリプトを読み込み
echo "DEBUG: Sourcing gitservice/${GITSERVICE}.sh" 1>&2
. "${SCRIPT_DIR}/gitservice/${GITSERVICE}.sh"
echo "DEBUG: Sourcing storage/${STORAGESERVICE}.sh" 1>&2
. "${SCRIPT_DIR}/storage/${STORAGESERVICE}.sh"
echo "DEBUG: Sourcing variables" 1>&2
. "${SCRIPT_DIR}/variables"
echo "DEBUG: All scripts sourced successfully" 1>&2

# PRに対する実行か否か
if ! is_change_request
then
    echo 'PRに対する実行ではありません。' 1>&2
    exit 1
fi

# ベースブランチの Understand データベースが存在しない場合は終了
if [ ! -d "${PREV_UND_DB_DIR}" ]
then
    echo 'ベースブランチの Understand データベースが存在しないため、変更された関数の解析は実行されませんでした。'
    exit 0
fi

# 作業用ファイル・ディレクトリ
functions_list_file=$(mktemp)
unique_names_list_file=$(mktemp)
images_dir=$(mktemp -d)
review_comment_table_file=$(mktemp)
review_comment_images_file=$(mktemp)

# スクリプト終了時のクリーンアップ
cleanup() {
    rm -rf "${functions_list_file}" "${unique_names_list_file}" "${images_dir}" "${review_comment_table_file}" "${review_comment_images_file}"
}
trap cleanup EXIT

# 変更された関数のリストを作成
und export -changes \
    -columns "Percent Changed,Long Name,File Name,Unique Name" \
    -kinds "Function, Procedure, Subroutine, Method" \
    -cmpdb "${PREV_UND_DB_DIR}" \
    "${functions_list_file}" \
    "${UND_DB_DIR}"
if [ $(wc --lines < "${functions_list_file}") -eq 1 ]
then
    echo '変更された関数はありません。'
    exit 0
fi
sed -i '1d; s/"//g' "${functions_list_file}"
sort --general-numeric-sort --reverse --output="${functions_list_file}" "${functions_list_file}"

# 変更された関数ごとに
cat "${functions_list_file}" | while IFS=, read -r rank function_name file_name unique_name
do
    # _export_graphics_.pl に渡すエンティティ名
    echo "${unique_name}" >> "${unique_names_list_file}"
    # レビューコメントの表
    echo "| ${function_name} | ${rank} | ${file_name} |" >> "${review_comment_table_file}"
    # レビューコメントの画像
    generate_pr_review_comment "${GIT_REPO_OWNER}" "${GIT_REPO_NAME}" "${GIT_COMMIT}" "${function_name}" "$(echo "${unique_name}" | sed -e 's/[\.:\/\\\\,\ @]/_/g')" "${file_name}" >> "${review_comment_images_file}"
done

# 変更された関数の画像を生成・アップロード
uperl "${SCRIPT_DIR}/_export_graphics_.pl" \
    -db "${UND_DB_DIR}" \
    -ents "${unique_names_list_file}" \
    -format svg \
    -report "Control Flow" \
    -dir "${images_dir}" \
    -options "Collapse=On;Comments=Off" \
    -variant "Compare" \
    1>&2
for image_file in "${images_dir}"/*.svg
do
    if [ "${image_file}" != "${images_dir}/*.svg" ]
    then
        put_image_file "${GIT_REPO_OWNER}" "${GIT_REPO_NAME}" "${GIT_COMMIT}" "${image_file}"
    fi
done

# レビューコメントを出力
cat <<-HEADER
以下の関数が変更されました。

| 関数 | Percent Changed | ファイル |
| -------- | -------- | -------- |
HEADER
cat "${review_comment_table_file}"
cat "${review_comment_images_file}"
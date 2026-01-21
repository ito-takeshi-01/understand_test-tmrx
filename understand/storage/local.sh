#!/bin/bash

# ローカルのベースディレクトリ（Windows環境の場合は適宜パスに変換）
LOCAL_BASE_DIR="/c/work/understand_data/test_prj"

# 引数
#repository_owner="$1"
#repository_name="$2"
#commit="$3"
#und_db_archive="$4"
repository_owner=${GIT_REPO_OWNER}
repository_name=${GIT_REPO_NAME}
commit=${PREV_COMMIT}
und_db_archive=${PREV_UND_DB_ARCHIVE}

# 保存先のディレクトリを作成
TARGET_DIR="${LOCAL_BASE_DIR}/${repository_owner}/${repository_name}/${commit}"
mkdir -p "${TARGET_DIR}"

# 1. ローカルからファイルを読み込む（例：データ取得）
get_analysis_data() {
  local source_file="${TARGET_DIR}/${und_db_archive}"
  if [ -f "${source_file}" ]; then
    echo "ファイルを読み込みました: ${source_file}"
    cat "${source_file}"
  else
    echo "ファイルが見つかりません: ${source_file}"
  fi
}

# 2. ローカルにファイルを保存（例：データ保存）
put_analysis_data() {
  local source_file="$1"
  local dest_file="${TARGET_DIR}/${und_db_archive}"
  cp "${source_file}" "${dest_file}"
  echo "ファイルを保存しました: ${dest_file}"
}

# 3. プルリクエストレビューコメントの生成（ローカルパスを使う）
generate_pr_review_comment() {
  local repository_owner="$1"
  local repository_name="$2"
  local commit="$3"
  local function_name="$4"
  local unique_name="$5"
  local image_file_name="$6"

  cat <<-END

  ### ${function_name} (${image_file_name})

  ![](${LOCAL_BASE_DIR}/${repository_owner}/${repository_name}/${commit}/images/${unique_name}.svg)

  -----
  END
}

# 4. 画像ファイルを保存
put_image_file() {
  local image_file="$1"
  local image_file_name="${image_file##*/}"
  local IMAGE_TARGET_DIR="${TARGET_DIR}/images"
  mkdir -p "${IMAGE_TARGET_DIR}"
  cp "${image_file}" "${IMAGE_TARGET_DIR}/${image_file_name}"
  echo "画像を保存しました: ${IMAGE_TARGET_DIR}/${image_file_name}"
}

# 使用例
# 例：リポジトリ情報とファイル名を指定して呼び出し
# ./your_script.sh owner_name repo_name commit_id und_db_archive.gz

# 例：データ取得
# get_analysis_data

# 例：データ保存（例：別の場所からコピーして保存）
# put_analysis_data "/path/to/source/file.gz"

# 例：画像保存
# put_image_file "/path/to/local/image.svg"

# 例：レビューコメント生成
# generate_pr_review_comment "owner" "repo" "commit" "関数名" "ユニーク名" "画像ファイル名.svg"

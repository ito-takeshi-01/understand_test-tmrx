#!/bin/bash
# シェルスクリプトのお作法として、どのシェルで動くかを明記

# ローカル保存先のルートディレクトリを定義
LOCAL_BASE_DIR="${LOCAL_STORAGE_PATH:-/c/work/understand_data/test_prj}"

# 1. 前回の解析データをローカルから取得する関数
get_analysis_data() {
    # 元のs3.shと同じように、引数をすべてローカル変数に格納する
    local repository_owner="$1"
    local repository_name="$2"
    local commit="$3"
    local und_db_archive="$4"

    # awsコマンドの代わりに、ローカルパスを組み立てる
    local TARGET_DIR="${LOCAL_BASE_DIR}/${repository_owner}/${repository_name}/${commit}"
    local source_file="${TARGET_DIR}/${und_db_archive}"

    # awsコマンドと同じ動作を再現：ファイルが存在すればカレントディレクトリにコピーする
    if [ -f "${source_file}" ]; then
        echo "Previous analysis data found. Copying from: ${source_file}"
        cp "${source_file}" .
        # if文で使えるように、成功（0）を返す
        return 0
    else
        echo "Previous analysis data not found: ${source_file}"
        # if文で使えるように、失敗（1）を返す
        return 1
    fi
}

# 2. 今回の解析データをローカルに保存する関数
put_analysis_data() {
    # 元のs3.shと同じように、引数をすべてローカル変数に格納する
    local repository_owner="$1"
    local repository_name="$2"
    local commit="$3"
    local source_file_path="$4" # 保存したいファイル（アーカイブ）のパス
    # source_file_pathからファイル名だけを抽出する
    local archive_file_name="${source_file_path##*/}"

    # awsコマンドの代わりに、ローカルパスを組み立てる
    local TARGET_DIR="${LOCAL_BASE_DIR}/${repository_owner}/${repository_name}/${commit}"
    # 保存先ディレクトリがなければ作成
    mkdir -p "${TARGET_DIR}"
    local dest_file="${TARGET_DIR}/${archive_file_name}"

    # awsコマンドと同じ動作を再現：指定されたファイルを宛先にコピーする
    echo "Saving analysis data to: ${dest_file}"
    cp "${source_file_path}" "${dest_file}"
}

# 3. GitHubコメント用の画像パスを生成する関数
generate_pr_review_comment() {
    local repository_owner="$1"
    local repository_name="$2"
    local commit="$3"
    local function_name="$4"
    local unique_name="$5"
    local file_name="$6"

    cat <<-END

        ### ${function_name} (${file_name})

        (Image cannot be displayed from local path: ${LOCAL_BASE_DIR}/${repository_owner}/${repository_name}/${commit}/images/${unique_name}.svg)

        -----
END
}

# 4. 生成された画像をローカルに保存する関数
put_image_file() {
    # 元のs3.shと同じように、引数をすべてローカル変数に格納する
    local repository_owner="$1"
    local repository_name="$2"
    local commit="$3"
    local source_image_path="$4" # 保存したい画像ファイルへのパス
    # source_image_pathからファイル名だけを抽出する
    local image_file_name="${source_image_path##*/}"

    # awsコマンドの代わりに、ローカルパスを組み立てる
    local IMAGE_TARGET_DIR="${LOCAL_BASE_DIR}/${repository_owner}/${repository_name}/${commit}/images"
    # 保存先ディレクトリがなければ作成
    mkdir -p "${IMAGE_TARGET_DIR}"
    local dest_file="${IMAGE_TARGET_DIR}/${image_file_name}"

    # awsコマンドと同じ動作を再現：画像を宛先にコピーする
    echo "Saving image file to: ${dest_file}"
    cp "${source_image_path}" "${dest_file}"
}
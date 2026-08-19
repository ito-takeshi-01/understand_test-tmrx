#!/bin/sh -eux

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 外部スクリプトの読み込み
. "$SCRIPT_DIR/gitservice/$GITSERVICE.sh"
. "$SCRIPT_DIR/storage/$STORAGESERVICE.sh"

# デバッグ: 利用可能なGit環境変数を表示
echo "DEBUG: GIT_COMMIT = '$GIT_COMMIT'" >&2
echo "DEBUG: GIT_PREVIOUS_COMMIT = '${GIT_PREVIOUS_COMMIT:-}'" >&2
echo "DEBUG: GIT_PREVIOUS_SUCCESSFUL_COMMIT = '${GIT_PREVIOUS_SUCCESSFUL_COMMIT:-}'" >&2
echo "DEBUG: CHANGE_ID = '${CHANGE_ID:-}'" >&2

# 比較対象のコミットを決定
if [ -n "${CHANGE_ID:-}" ]; then
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

# 変数ファイルを読み込み
. "$SCRIPT_DIR/variables"

echo "DEBUG: PREV_UND_DB_DIR = '$PREV_UND_DB_DIR'" >&2
echo "DEBUG: UND_DB_DIR = '$UND_DB_DIR'" >&2

# 比較DBの設定確認
if [ -d "$SCRIPT_DIR/$PREV_UND_DB_DIR" ]; then
    echo "DEBUG: Using comparison DB: $PREV_UND_DB_DIR" >&2
else
    echo "DEBUG: No comparison DB found, generating graphs without comparison" >&2
fi

# 変更された関数のリストを取得
functions_list_file=$(mktemp)
echo "DEBUG: Exporting changes..." >&2
echo "DEBUG: Command: und export -db \"$UND_DB_DIR\" -changes -columns \"PercentChanged,Long Name,File Name,Unique Name\" -kinds \"Function, Procedure, Subroutine, Method\" \"$functions_list_file\"" >&2

und export -db "$SCRIPT_DIR/$UND_DB_DIR" -changes -columns "PercentChanged,Long Name,File Name,Unique Name" -kinds "Function, Procedure, Subroutine, Method" "$functions_list_file" 2>&1 | tee /dev/stderr || true

# ファイル内容をデバッグ出力
echo "DEBUG: functions_list_file content:" >&2
cat "$functions_list_file" >&2
echo "DEBUG: Line count: $(wc -l < "$functions_list_file")" >&2

# 一時ディレクトリを作成
temp_dir=$(mktemp -d)
echo "DEBUG: Temporary directory: $temp_dir" >&2

# ヘッダー行をスキップして、2行目以降を処理
tail -n +2 "$functions_list_file" | while IFS=, read -r percent_changed long_name file_name unique_name || [ -n "$unique_name" ]
do
    # クォートを削除
    percent_changed=$(echo "$percent_changed" | sed 's/"//g')
    long_name=$(echo "$long_name" | sed 's/"//g')
    file_name=$(echo "$file_name" | sed 's/"//g')
    unique_name=$(echo "$unique_name" | sed 's/"//g')
    
    echo "DEBUG: Processing function: $long_name in $file_name (Changed: $percent_changed)" >&2
    
    # 安全なファイル名を生成（特殊文字を置換）
    safe_unique_name=$(echo "$unique_name" | sed 's/[@\/\.]/_/g')
    svg_file="$temp_dir/${safe_unique_name}.svg"
    
    echo "DEBUG: Generating graph for: $long_name -> $svg_file" >&2
    
    # グラフを生成
    if und export -db "$SCRIPT_DIR/$UND_DB_DIR" "$unique_name" controlflow "$svg_file" 2>&1 | tee /dev/stderr
    then
        if [ -f "$svg_file" ]; then
            echo "DEBUG: Graph generated: $long_name -> $svg_file" >&2
            
            # 画像ファイル名を生成
            image_filename="${safe_unique_name}.svg"
            image_output_path=$(get_image_storage_path "$GIT_REPO_OWNER" "$GIT_REPO_NAME" "$GIT_COMMIT" "$image_filename")
            
            # 画像を保存（デバッグメッセージはstderrへ）
            echo "DEBUG: Saving image to: $image_output_path" >&2
            if put_image "$GIT_REPO_OWNER" "$GIT_REPO_NAME" "$GIT_COMMIT" "$svg_file" "$image_output_path"
            then
                echo "DEBUG: Image saved successfully: $image_output_path" >&2
                
                # GitHubのraw URLを生成
                if [ "$STORAGESERVICE" = "local" ]; then
                    IMAGE_URL="file://$image_output_path"
                    echo "DEBUG: Local image URL: $IMAGE_URL" >&2
                else
                    IMAGE_URL=$(get_image_url "$GIT_REPO_OWNER" "$GIT_REPO_NAME" "$GIT_COMMIT" "$image_filename")
                    echo "DEBUG: Remote image URL: $IMAGE_URL" >&2
                fi
                
                # マークダウン形式で出力（stdoutへ - これがPRコメントになる）
                echo "## 🔄 関数: \`$long_name\` (変更率: $percent_changed)"
                echo ""
                echo "**ファイル:** \`$file_name\`"
                echo ""
                echo "### 制御フローグラフ"
                echo ""
                
                if [ "$STORAGESERVICE" = "local" ]; then
                    echo "> ⚠️ ローカルストレージモード: 画像は \`$image_output_path\` に保存されています"
                else
                    echo "![Control Flow Graph]($IMAGE_URL)"
                fi
                
                echo ""
                echo "---"
                echo ""
            else
                echo "⚠️ 警告: 画像の保存に失敗しました: $long_name" >&2
            fi
        else
            echo "⚠️ 警告: グラフファイルが生成されませんでした: $long_name" >&2
        fi
    else
        echo "⚠️ 警告: グラフの生成に失敗しました: $long_name" >&2
    fi
done

# 変更された関数がない場合
if [ $(wc -l < "$functions_list_file") -le 1 ]; then
    echo "✅ 変更された関数はありません。"
fi

# 一時ファイルとディレクトリをクリーンアップ
rm -f "$functions_list_file"
rm -rf "$temp_dir"

echo "DEBUG: Graph generation completed" >&2
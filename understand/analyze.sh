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
echo "DEBUG: SCRIPT_DIR = '$SCRIPT_DIR'" >&2
echo "DEBUG: WORKSPACE = '${WORKSPACE:-$(dirname "$SCRIPT_DIR")}'" >&2

# ワークスペースのパスを取得
WORKSPACE_DIR="${WORKSPACE:-$(dirname "$SCRIPT_DIR")}"

# 前回の解析データを取得
if get_analysis_data "$GIT_REPO_OWNER" "$GIT_REPO_NAME" "$PREV_COMMIT" "$PREV_UND_DB_ARCHIVE"
then
    echo "DEBUG: Extracting previous DB archive..." >&2
    tar xzf "$PREV_UND_DB_ARCHIVE" -C "$SCRIPT_DIR"
    rm -rf "$PREV_UND_DB_ARCHIVE"
    
    # 既存のDBがあれば削除
    rm -rf "$SCRIPT_DIR/$UND_DB_DIR"
    
    # 前回のDBをコピーして新しいDBを作成
    echo "DEBUG: Copying previous DB: $PREV_UND_DB_DIR -> $UND_DB_DIR" >&2
    cp -r "$SCRIPT_DIR/$PREV_UND_DB_DIR" "$SCRIPT_DIR/$UND_DB_DIR"
    
    # 比較設定
    echo "DEBUG: Setting comparison DB..." >&2
    und settings -ComparisonProjectPath "$SCRIPT_DIR/$PREV_UND_DB_DIR" "$SCRIPT_DIR/$UND_DB_DIR"
    
    # ワークスペースに移動
    cd "$WORKSPACE_DIR"
    echo "DEBUG: Changed to workspace: $(pwd)" >&2
    echo "DEBUG: Listing workspace contents:" >&2
    ls -la | head -20 >&2
    
    # 変更されたファイルを取得
    echo "DEBUG: Getting changed files between $PREV_COMMIT and $GIT_COMMIT..." >&2
    CHANGED_FILES=$(git diff --name-only --diff-filter=ACMR "$PREV_COMMIT" "$GIT_COMMIT" | grep '\.[ch]$' || true)
    
    if [ -z "$CHANGED_FILES" ]; then
        echo "DEBUG: No changed C/C++ files detected, searching recursively for all C/H files..." >&2
        # すべてのサブディレクトリを再帰的に検索（.git と understand ディレクトリを除外）
        CHANGED_FILES=$(find . -type f \\( -name "*.c" -o -name "*.h" \\) ! -path "./.git/*" ! -path "./understand/*" | sed 's|^\./||')
        
        # ファイル数をカウント
        FILE_COUNT=$(echo "$CHANGED_FILES" | grep -c . || echo 0)
        echo "DEBUG: Found $FILE_COUNT C/H files" >&2
        
        if [ $FILE_COUNT -gt 0 ]; then
            echo "DEBUG: First 10 files found:" >&2
            echo "$CHANGED_FILES" | head -10 >&2
        fi
    fi
    
    if [ -n "$CHANGED_FILES" ]; then
        echo "DEBUG: Files to add/update:" >&2
        echo "$CHANGED_FILES" >&2
        
        # ファイルをDBに追加
        for file in $CHANGED_FILES; do
            if [ -f "$file" ]; then
                echo "DEBUG: Adding file: $file" >&2
                und add "$file" "$SCRIPT_DIR/$UND_DB_DIR"
            else
                echo "DEBUG: File not found (may be deleted): $file" >&2
            fi
        done
        
        # 解析を実行
        echo "DEBUG: Analyzing database..." >&2
        und analyze "$SCRIPT_DIR/$UND_DB_DIR"
        
        # 解析後のファイル一覧を確認
        echo "DEBUG: Files in DB after analysis:" >&2
        und list files -db "$SCRIPT_DIR/$UND_DB_DIR" >&2
    else
        echo "WARNING: No files to analyze" >&2
    fi
    
    # understand ディレクトリに戻る
    cd "$SCRIPT_DIR"
    
else
    # 初回の解析（前回のデータがない場合）
    echo "DEBUG: No previous analysis data found. Creating new database." >&2
    
    # 既存のDBを削除
    rm -rf "$SCRIPT_DIR/$UND_DB_DIR"
    
    # 新しいDBを作成
    echo "DEBUG: Creating new database..." >&2
    und create -db "$SCRIPT_DIR/$UND_DB_DIR"
    mkdir -p "$SCRIPT_DIR/$UND_DB_DIR/local"
    
    # 設定を適用
    if [ -f "$SCRIPT_DIR/settings" ]; then
        echo "DEBUG: Applying settings from settings file..." >&2
        und settings @"$SCRIPT_DIR/settings" -db "$SCRIPT_DIR/$UND_DB_DIR"
    fi
    
    # ワークスペースに移動
    cd "$WORKSPACE_DIR"
    echo "DEBUG: Changed to workspace: $(pwd)" >&2
    echo "DEBUG: Listing workspace contents:" >&2
    ls -la | head -20 >&2
    
    # ファイルリストを確認
    if [ -f "$SCRIPT_DIR/files" ]; then
        echo "DEBUG: Adding files from files list..." >&2
        und add @"$SCRIPT_DIR/files" -db "$SCRIPT_DIR/$UND_DB_DIR"
    else
        # filesファイルがない場合、すべてのC/Cファイルを再帰的に追加
        echo "DEBUG: No files list found, searching recursively for all C/H files..." >&2
        # すべてのサブディレクトリを再帰的に検索（.git と understand ディレクトリを除外）
        FILES_TO_ADD=$(find . -type f \\( -name "*.c" -o -name "*.h" \\) ! -path "./.git/*" ! -path "./understand/*" | sed 's|^\./||')
        
        # ファイル数をカウント
        FILE_COUNT=$(echo "$FILES_TO_ADD" | grep -c . || echo 0)
        echo "DEBUG: Found $FILE_COUNT C/H files" >&2
        
        if [ $FILE_COUNT -gt 0 ]; then
            echo "DEBUG: First 10 files found:" >&2
            echo "$FILES_TO_ADD" | head -10 >&2
            
            # ファイルをDBに追加
            for file in $FILES_TO_ADD; do
                if [ -f "$file" ]; then
                    echo "DEBUG: Adding file: $file" >&2
                    und add "$file" "$SCRIPT_DIR/$UND_DB_DIR"
                fi
            done
        else
            echo "ERROR: No C/C++ files found to analyze" >&2
            exit 1
        fi
    fi
    
    # 解析を実行
    echo "DEBUG: Analyzing database (initial)..." >&2
    und analyze "$SCRIPT_DIR/$UND_DB_DIR"
    
    # 解析後のファイル一覧を確認
    echo "DEBUG: Files in DB after initial analysis:" >&2
    und list files -db "$SCRIPT_DIR/$UND_DB_DIR" >&2
    
    # understand ディレクトリに戻る
    cd "$SCRIPT_DIR"
fi

# DBをアーカイブ
echo "DEBUG: Creating archive: $UND_DB_ARCHIVE" >&2
tar czf "$SCRIPT_DIR/$UND_DB_ARCHIVE" -C "$SCRIPT_DIR" "$UND_DB_DIR"

# アーカイブサイズを確認
if [ -f "$SCRIPT_DIR/$UND_DB_ARCHIVE" ]; then
    ARCHIVE_SIZE=$(ls -lh "$SCRIPT_DIR/$UND_DB_ARCHIVE" | awk '{print $5}')
    echo "DEBUG: Archive size: $ARCHIVE_SIZE" >&2
fi

# 解析データをアップロード
if [ "${1:-}" = '--upload' ]
then
    echo "DEBUG: Uploading analysis data..." >&2
    put_analysis_data "$GIT_REPO_OWNER" "$GIT_REPO_NAME" "$GIT_COMMIT" "$SCRIPT_DIR/$UND_DB_ARCHIVE"
fi

echo "Analyze Completed (Errors:0 Warnings:0)" >&2

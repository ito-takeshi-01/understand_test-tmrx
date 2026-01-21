#!/bin/sh -eux

# 外部スクリプトの読み込み
. "${0%/*}/variables"
. "${0%/*}/gitservice/${GITSERVICE}.sh"
. "${0%/*}/storage/${STORAGESERVICE}.sh"
#. "${0%/*}/variables"

# 前回の解析データを取得
if get_analysis_data "${GIT_REPO_OWNER}" "${GIT_REPO_NAME}" "${PREV_COMMIT}" "${PREV_UND_DB_ARCHIVE}"
then
	# 前回の解析データを使用して Understand データベースを作成
	tar xzf "${PREV_UND_DB_ARCHIVE}"                                                      # アーカイブ（${PREV_UND_DB_ARCHIVE}）を展開し、前回のUnderstandデータベースを復元
	rm -rf "${PREV_UND_DB_ARCHIVE}"                                                       # 古いデータやディレクトリを削除し、新しいデータベースを作成
	rm -rf "${UND_DB_DIR}"
	und create -db "${UND_DB_DIR}" -gitcommit "${GIT_COMMIT}" -refdb "${PREV_UND_DB_DIR}" # コマンドで新しいUnderstandデータベースを作成
	und settings -ComparisonProjectPath "${PREV_UND_DB_DIR}" "${UND_DB_DIR}"              # 前回のリファレンスデータと比較設定を行う
else
	# 前回の解析データを使用せずに Understand データベースを作成
	rm -rf "${UND_DB_DIR}"                                    # 既存のデータベースディレクトリを削除
	und create -db "${UND_DB_DIR}" -gitcommit "${GIT_COMMIT}" # 新規にund createでデータベースを作成
	mkdir -p "${UND_DB_DIR}/local"                            # 設定ファイルやファイルリストを追加し、データベースを構築
	und settings @"${0%/*}/settings" -db "${UND_DB_DIR}"      
	und add @"${0%/*}/files" -db "${UND_DB_DIR}"
fi

# 解析を実行
und analyze "${UND_DB_DIR}"                 # 指定したデータベースに対して静的解析を実行
tar czf "${UND_DB_ARCHIVE}" "${UND_DB_DIR}" # 解析後のデータベースディレクトリを圧縮し、アーカイブファイル${UND_DB_ARCHIVE}に保存

# 解析データをアップロード
if [ "${1:-}" = '--upload' ]
then
	put_analysis_data "${GIT_REPO_OWNER}" "${GIT_REPO_NAME}" "${GIT_COMMIT}" "${UND_DB_ARCHIVE}" # 解析データ（アーカイブ）をリモートストレージやサーバにアップロード
fi

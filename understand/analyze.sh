#!/bin/sh -eux

. "${0%/*}/gitservice/${GITSERVICE}.sh"
. "${0%/*}/storage/${STORAGESERVICE}.sh"
. "${0%/*}/variables"

# 前回の解析データを取得
if get_analysis_data "${GIT_REPO_OWNER}" "${GIT_REPO_NAME}" "${PREV_COMMIT}" "${PREV_UND_DB_ARCHIVE}"
then
	# 前回の解析データを使用して Understand データベースを作成
	tar xzf "${PREV_UND_DB_ARCHIVE}"
	rm -rf "${PREV_UND_DB_ARCHIVE}"
	rm -rf "${UND_DB_DIR}"
	und create -db "${UND_DB_DIR}" -gitcommit "${GIT_COMMIT}" -refdb "${PREV_UND_DB_DIR}"
	und settings -ComparisonProjectPath "${PREV_UND_DB_DIR}" "${UND_DB_DIR}"
else
	# 前回の解析データを使用せずに Understand データベースを作成
	rm -rf "${UND_DB_DIR}"
	und create -db "${UND_DB_DIR}" -gitcommit "${GIT_COMMIT}"
	mkdir -p "${UND_DB_DIR}/local"
	und settings @"${0%/*}/settings" -db "${UND_DB_DIR}"
	und add @"${0%/*}/files" -db "${UND_DB_DIR}"
fi

# 解析を実行
und analyze "${UND_DB_DIR}"
tar czf "${UND_DB_ARCHIVE}" "${UND_DB_DIR}"

# 解析データをアップロード
if [ "${1:-}" = '--upload' ]
then
	put_analysis_data "${GIT_REPO_OWNER}" "${GIT_REPO_NAME}" "${GIT_COMMIT}" "${UND_DB_ARCHIVE}"
fi

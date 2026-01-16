GIT_REPO_OWNER="$(echo "${GIT_URL}" | sed -E 's,.*[:/]([^/]*)/[^/]*.git,\1,')"
GIT_REPO_NAME="$(echo "${GIT_URL}" | sed -E 's,.*/([^/]*).git,\1,')"

# PRか否か
is_change_request() {
	test -n "${CHANGE_ID:-}"
}

if is_change_request
then
	# マージ先のブランチ
	PREV_COMMIT=$(git merge-base --fork-point origin/${CHANGE_TARGET})
else
	# ビルドが成功した最後のコミット
	PREV_COMMIT="${GIT_PREVIOUS_SUCCESSFUL_COMMIT:-0}"
fi

# PRにレビューコメントを追加
post_review_comment() {
	local data_file="$1"
	sed -i -zE 's/\n/\\n/g ; s/(.*)/{"body":"\1"}/' "${data_file}"
	curl --user "${GITEA_CRED}" --insecure --silent --request POST \
		"${GITEA_URL}/api/v1/repos/${GIT_REPO_OWNER}/${GIT_REPO_NAME}/pulls/${CHANGE_ID}/reviews" \
		--header 'Accept: application/json' \
		--header 'Content-Type: application/json' \
		--data @"${data_file}"
}

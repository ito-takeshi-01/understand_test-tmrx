GIT_REPO_OWNER="$(echo "${CI_REPOSITORY_URL}" | sed -E 's,.*[:/]([^/]*)/[^/]*.git,\1,')"
GIT_REPO_NAME="$(echo "${CI_REPOSITORY_URL}" | sed -E 's,.*/([^/]*).git,\1,')"
CI_PROJECT="$(echo "${CI_MERGE_REQUEST_PROJECT_PATH}" | sed -E 's/\//%2F/g')" 

# PRか否か
is_change_request() {
	test "${CI_PIPELINE_SOURCE}" = 'merge_request_event'
}

if is_change_request
then
	# マージ先ブランチのHEAD
	PREV_COMMIT=$(git log -n 1 --format='%H' origin/${CI_MERGE_REQUEST_TARGET_BRANCH_NAME})
else
	# 一つ前のコミット
	PREV_COMMIT="${CI_COMMIT_BEFORE_SHA:-0}"
fi


post_review_comment() {
	local data_file="$1"
	sed -i -zE 's/\n/\\n/g ; s/(.*)/{"body":"\1"}/' "${data_file}"
	curl  -X "POST" --header "Private-Token: ${CI_ACCESS_TOKEN}" \
		"${CI_API_V4_URL}/projects/${CI_PROJECT}/merge_requests/${CI_MERGE_REQUEST_IID}/notes" \
		--header 'Accept: application/json' \
		--header 'Content-Type: application/json' \
		-d @"${data_file}"
}

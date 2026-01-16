GIT_REPO_OWNER="${GITHUB_REPOSITORY%/*}"
GIT_REPO_NAME="${GITHUB_REPOSITORY##*/}"

# PRか否か
is_change_request() {
	test "${GITHUB_EVENT_NAME}" = 'pull_request'
}

if is_change_request
then
	# マージ先ブランチのHEAD
	PREV_COMMIT=${GIT_BASE_COMMIT:-$(git merge-base --fork-point origin/${CHANGE_TARGET})}
else
	# 一つ前のコミット
	PREV_COMMIT="$(git show --summary --format=%H HEAD^)"
fi

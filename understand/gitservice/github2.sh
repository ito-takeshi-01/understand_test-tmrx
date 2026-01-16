# GitHub APIのURL（必要に応じて変更）
GITHUB_API_URL="${GITHUB_API_URL:-https://api.github.com}"

# GitHubのパーソナルアクセストークン（事前に環境変数GITHUB_TOKENを設定してください）
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

# GIT_URLからリポジトリの所有者（ユーザ名または組織名）とリポジトリ名を抽出
GIT_REPO_OWNER="$(echo "${GIT_URL}" | sed -E 's,.*[:/]([^/]*)/[^/]*.git,\1,')"
GIT_REPO_NAME="$(echo "${GIT_URL}" | sed -E 's,.*/([^/]*).git,\1,')"

# PR(Pull Request)か否か
is_change_request() {
    test -n "${CHANGE_ID:-}"
}

if is_change_request
then
    # PRの場合、マージ先のブランチとPRの差分の共通コミットを取得
    PREV_COMMIT=$(git merge-base --fork-point origin/${CHANGE_TARGET})
else
    # 通常ビルドの場合、ビルドが成功した最後のコミットに設定
    PREV_COMMIT="${GIT_PREVIOUS_SUCCESSFUL_COMMIT:-0}"
fi

# PRにレビューコメントを追加（GitHub用に修正）
post_review_comment() {
    local data_file="$1"  # コメント内容が書かれたファイル
    sed -i -zE 's/\n/\\n/g ; s/(.*)/{"body":"\1"}/' "${data_file}"
    curl --silent --request POST \
        -H "Authorization: token ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Content-Type: application/json" \
        "${GITHUB_API_URL}/repos/${GIT_REPO_OWNER}/${GIT_REPO_NAME}/pulls/${CHANGE_ID}/reviews" \
        --data @"${data_file}"
}
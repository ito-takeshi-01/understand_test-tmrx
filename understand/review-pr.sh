#!/bin/sh -eux




# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

. "${SCRIPT_DIR}/gitservice/${GITSERVICE}.sh"
. "${SCRIPT_DIR}/storage/${STORAGESERVICE}.sh"
. "${SCRIPT_DIR}/variables"




# 外部スクリプトの読み込み
. "${0%/*}/gitservice/${GITSERVICE}.sh"
. "${0%/*}/storage/${STORAGESERVICE}.sh"
. "${0%/*}/variables"

comment_file="$1"
post_review_comment "${comment_file}"

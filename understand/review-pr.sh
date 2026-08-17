#!/bin/sh -eux

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/gitservice/$GITSERVICE.sh"
. "$SCRIPT_DIR/storage/$STORAGESERVICE.sh"
. "$SCRIPT_DIR/variables"

comment_file="$1"
post_review_comment "$GIT_REPO_OWNER" "$GIT_REPO_NAME" "$CHANGE_ID" "$comment_file"

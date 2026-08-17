#!/bin/sh -eux

. "${0%/*}/gitservice/${GITSERVICE}.sh"
. "${0%/*}/storage/${STORAGESERVICE}.sh"
. "${0%/*}/variables"

comment_file="$1"
post_review_comment "${comment_file}"

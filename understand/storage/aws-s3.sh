get_analysis_data() {
	local repository_owner="$1"
	local repository_name="$2"
	local commit="$3"
	local und_db_archive="$4"

	aws s3api get-object \
		--bucket "${AWS_S3_BUCKET_NAME}" \
		--key "${repository_owner}/${repository_name}/${commit}/${und_db_archive}" \
		"${und_db_archive}" 1>&2
}

put_analysis_data() {
	local repository_owner="$1"
	local repository_name="$2"
	local commit="$3"
	local und_db_archive="$4"

	aws s3api put-object \
		--body "${und_db_archive}" \
		--bucket "${AWS_S3_BUCKET_NAME}" \
		--key "${repository_owner}/${repository_name}/${commit}/${und_db_archive}" \
		--content-type 'application/x-gzip'
}

generate_pr_review_comment() {
	local repository_owner="$1"
	local repository_name="$2"
	local commit="$3"
	local function_name="$4"
	local unique_name="$5"
	local image_file_name="$6"

	cat <<-END

		### ${function_name} (${image_file_name})

		![](https://${AWS_S3_BUCKET_NAME}.s3.amazonaws.com/${repository_owner}/${repository_name}/${commit}/images/${unique_name}.svg)

		-----
	END
}

put_image_file() {
	local repository_owner="$1"
	local repository_name="$2"
	local commit="$3"
	local image_file="$4"
	local image_file_name="${image_file##*/}"

	aws s3api put-object \
		--body "${image_file}" \
		--bucket "${AWS_S3_BUCKET_NAME}" \
		--key "${repository_owner}/${repository_name}/${commit}/images/${image_file_name}" \
		--content-type "image/svg+xml" \
		1>&2
}

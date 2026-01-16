get_analysis_data() {
	local repository_owner="$1"
	local repository_name="$2"
	local commit="$3"
	local und_db_archive="$4"

	curl --fail --netrc-file "${NEXUS_CREDENTIALS_FILE}" --insecure --silent -o "${und_db_archive}" \
		"${NEXUS_URL}/repository/${repository_owner}/${repository_name}%2F${commit}%2F${und_db_archive}"
}

put_analysis_data() {
	local repository_owner="$1"
	local repository_name="$2"
	local commit="$3"
	local und_db_archive="$4"

	curl --netrc-file "${NEXUS_CREDENTIALS_FILE}" --insecure --silent --request POST \
		"${NEXUS_URL}/service/rest/v1/components?repository=${repository_owner}" \
		--form raw.directory="${repository_name}/${commit}" \
		--form raw.asset1="@${und_db_archive}" \
		--form raw.asset1.filename="${und_db_archive}"
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

		![](${NEXUS_URL}/repository/${repository_owner}/${repository_name}%2F${commit}%2Fimages%2F${unique_name}.svg)

		-----
	END
}

put_image_file() {
	local repository_owner="$1"
	local repository_name="$2"
	local commit="$3"
	local image_file="$4"
	local image_file_name="${image_file##*/}"

	curl --netrc-file "${NEXUS_CREDENTIALS_FILE}" --insecure --silent -request POST \
		"${NEXUS_URL}/service/rest/v1/components?repository=${repository_owner}" \
		--form raw.directory="${repository_name}/${commit}/images" \
		--form raw.asset1="@${image_file}" \
		--form raw.asset1.filename="${image_file_name}" \
		1>&2
}

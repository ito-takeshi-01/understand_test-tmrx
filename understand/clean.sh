#!/bin/sh -x

UND_DB_DIR="cgit-${GIT_COMMIT:=$(git show --summary --format=%H)}.und"

und purge "${UND_DB_DIR}"
rm -rf cgit-*.und cgit-*.und.tar.gz

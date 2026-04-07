#!/bin/sh -x

. "${0%/*}/variables"

# und purge が失敗しても cleanup 自体は続行
und purge "${UND_DB_DIR}" || true
rm -rf "${UND_DB_DIR}" "${UND_DB_ARCHIVE}"

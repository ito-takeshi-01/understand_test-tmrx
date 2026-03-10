#!/bin/sh -x

# プロキシ設定用の環境変数（PROXY_HOST, PROXY_PORT）がJenkinsfileから渡されているか確認し、
# 存在すればundコマンドをプロキシ設定付きのエイリアス（別名）で上書きする。
# これにより、このスクリプト内で `und` と呼び出すと、プロキシ設定付きのコマンドが実行される。
if [ -n "${PROXY_HOST:-}" ] && [ -n "${PROXY_PORT:-}" ]; then
    alias und="und -proxyhost ${PROXY_HOST} -proxyport ${PROXY_PORT} -proxycreds ''"
fi

UND_DB_DIR="cgit-${GIT_COMMIT:=$(git show --summary --format=%H)}.und"

und purge "${UND_DB_DIR}"
rm -rf cgit-*.und cgit-*.und.tar.gz

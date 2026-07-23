#!/bin/sh -eux

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 外部スクリプトの読み込み
. "$SCRIPT_DIR/variables"

# データベースをクリーンアップ
und purge "$UND_DB_DIR"
rm -rf "$UND_DB_DIR"
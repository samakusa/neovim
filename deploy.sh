#!/bin/bash

# 設定ファイルのコピー先
NVIM_CONFIG_DIR="$HOME/.config/nvim"

# このスクリプトが存在するディレクトリ（=プロジェクトのルート）
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# コピー先ディレクトリがなければ作成
mkdir -p "$NVIM_CONFIG_DIR"

echo "Deploying Neovim config to $NVIM_CONFIG_DIR..."

# rsyncでファイルを同期
# --excludeで不要なファイルやディレクトリを除外する
rsync -av --delete \
  --exclude=".git" \
  --exclude="node_modules" \
  --exclude="docs" \
  --exclude=".gitignore" \
  --exclude="package.json" \
  --exclude="package-lock.json" \
  --exclude="deploy.sh" \
  "$SOURCE_DIR/" "$NVIM_CONFIG_DIR/"

echo "Done."

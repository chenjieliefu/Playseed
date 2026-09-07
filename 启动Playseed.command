#!/bin/zsh
set -eu
PLAYSEED_DIR="${0:A:h}"
if [[ ! -d "$PLAYSEED_DIR/Playseed.app" ]]; then
  print '请先在项目目录生成 Playseed.app。'
  read '?按回车关闭'
  exit 1
fi
exec /usr/bin/open "$PLAYSEED_DIR/Playseed.app"

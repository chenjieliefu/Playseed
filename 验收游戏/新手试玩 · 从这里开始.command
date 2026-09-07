#!/bin/zsh
cd "$(dirname "$0")/.." || exit 1
python3 scripts/novice_playtest.py
if [[ $? -ne 0 ]]; then
  read "?未能打开试玩。请保留上方提示，按回车关闭。"
fi

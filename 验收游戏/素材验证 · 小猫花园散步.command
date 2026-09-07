#!/bin/zsh
cd "$(dirname "$0")/.."
python3 scripts/check_visual_suite.py --play

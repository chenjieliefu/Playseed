#!/bin/zsh
cd "$(dirname "$0")/.." || exit 1
python3 scripts/play_validation.py p2-20260907 progression --revision 4

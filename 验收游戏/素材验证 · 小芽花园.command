#!/bin/zsh
cd "$(dirname "$0")/.."
python3 scripts/check_image_validation.py "2026-09-06T18-58-59+08-00" --play

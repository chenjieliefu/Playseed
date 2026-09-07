#!/bin/zsh
cd "$(dirname "$0")/.." || exit 1
python3 scripts/play_audio_validation.py

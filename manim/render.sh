#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -d "manim/.venv" ]; then
  python3 -m venv manim/.venv
fi

source manim/.venv/bin/activate
pip install -r manim/requirements.txt
manim -pqh manim/needleman_wunsch_scene.py NeedlemanWunschDemo

mkdir -p manim/output
cp media/videos/needleman_wunsch_scene/800p30/NeedlemanWunschDemo.mp4 \
  manim/output/NeedlemanWunschDemo.mp4

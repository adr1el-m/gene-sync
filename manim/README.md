# GeneSync Manim Scene

This folder contains the Manim animation for the Needleman-Wunsch presentation segment.

## Scene

- File: `needleman_wunsch_scene.py`
- Scene class: `NeedlemanWunschDemo`
- Background color: `#FEFAF4`
- Output ratio: `2:1`, matching the provided reference layout

## Render

From the repository root:

```sh
python3 -m venv manim/.venv
source manim/.venv/bin/activate
pip install -r manim/requirements.txt
manim -pqh manim/needleman_wunsch_scene.py NeedlemanWunschDemo
```

For a faster preview:

```sh
manim -pql manim/needleman_wunsch_scene.py NeedlemanWunschDemo
```

Rendered videos are written under `media/videos/needleman_wunsch_scene/`.
The helper script also copies the final MP4 to:

```text
manim/output/NeedlemanWunschDemo.mp4
```

#!/usr/bin/env python3
"""Move baked floor above VisionLayer so neon shader skips stone tiles."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCENES = ("main.tscn", "sala1.tscn", "sala2.tscn")

FLOOR_LAYER = """
[node name="FloorLayer" type="CanvasLayer" parent="."]
layer = 125
follow_viewport_enabled = true

"""

SCRIPT_EXT = '[ext_resource type="Script" path="res://scripts/floor_reveal.gd" id="floor_reveal"]\n'


def patch(path: Path) -> None:
    text = path.read_text(encoding="utf-8")

    if "floor_reveal.gd" not in text:
        first_ext = text.find("[ext_resource")
        text = text[:first_ext] + SCRIPT_EXT + text[first_ext:]

    text = text.replace('parent="World/Hub/Floor"', 'parent="FloorLayer/Floor"')
    text = re.sub(
        r'\[node name="Floor" type="Node2D" parent="World/Hub"\]',
        '[node name="Floor" type="Node2D" parent="FloorLayer"]\nscript = ExtResource("floor_reveal")',
        text,
        count=1,
    )

    if '[node name="FloorLayer" type="CanvasLayer"' not in text:
        marker = '[node name="VisionLayer" type="CanvasLayer"'
        if marker not in text:
            raise SystemExit(f"No VisionLayer in {path.name}")
        text = text.replace(marker, FLOOR_LAYER.strip() + "\n\n" + marker, 1)

    ext = len(re.findall(r"^\[ext_resource", text, re.M))
    sub = len(re.findall(r"^\[sub_resource", text, re.M))
    text = re.sub(r"load_steps=\d+", f"load_steps={ext + sub + 1}", text, count=1)
    path.write_text(text, encoding="utf-8")
    print(path.name, "floor -> FloorLayer (above vision)")


def main() -> None:
    for name in SCENES:
        patch(ROOT / "scenes" / name)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Add FloorTiler node to hub scenes."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

FLOOR_BY_SCENE = {
    "main.tscn": 101,
    "sala1.tscn": 202,
    "sala2.tscn": 303,
}

FLOOR_BLOCK = """
[node name="Floor" type="Node2D" parent="World/Hub"]
z_index = -95
script = ExtResource("FLOOR_SCRIPT")
layout_seed = {seed}
"""


def patch(path: Path, seed: int) -> None:
    text = path.read_text(encoding="utf-8")
    script_line = '[ext_resource type="Script" path="res://scripts/floor_tiler.gd" id="floor_tiler"]\n'
    if "floor_tiler.gd" not in text:
        idx = text.find("\n", text.find("[ext_resource"))
        text = text[: idx + 1] + script_line + text[idx + 1 :]
    text = text.replace(
        'script = ExtResource("FLOOR_SCRIPT")',
        'script = ExtResource("floor_tiler")',
    )
    if '[node name="Floor" type="Node2D" parent="World/Hub"]' in text:
        text = re.sub(r"layout_seed = \d+", f"layout_seed = {seed}", text, count=1)
    else:
        marker = "polygon = PackedVector2Array(-1170, -690, 1170, -690, 1170, 690, -1170, 690)"
        block = FLOOR_BLOCK.format(seed=seed).strip() + "\n\n"
        if marker in text:
            text = text.replace(marker, marker + "\n\n" + block, 1)
        else:
            raise SystemExit(f"No Backdrop polygon in {path.name}")

    ext = len(re.findall(r"^\[ext_resource", text, re.M))
    sub = len(re.findall(r"^\[sub_resource", text, re.M))
    text = re.sub(r"load_steps=\d+", f"load_steps={ext + sub + 1}", text, count=1)
    path.write_text(text, encoding="utf-8")
    print(path.name, "floor seed", seed)


def main() -> None:
    for name, seed in FLOOR_BY_SCENE.items():
        patch(ROOT / "scenes" / name, seed)


if __name__ == "__main__":
    main()

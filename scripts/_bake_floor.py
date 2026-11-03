#!/usr/bin/env python3
"""Bake stone floor tiles into hub scenes; remove black Backdrop fill."""
from __future__ import annotations

import random
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCENES = ROOT / "scenes"

AREA_MIN = (-1170, -690)
AREA_MAX = (1170, 690)
TILE_PX = 32
TILE_SCALE = 4.0
STEP = TILE_PX * TILE_SCALE

TEXTURES = [
    ("pedra_1", "res://assets/floor/pedra_1.png"),
    ("pedra_2", "res://assets/floor/pedra_2.png"),
    ("pedra_3", "res://assets/floor/pedra_3.png"),
    ("pedra_4", "res://assets/floor/pedra_4.png"),
    ("pedra_5", "res://assets/floor/pedra_5.png"),
]

SEEDS = {"main.tscn": 101, "sala1.tscn": 202, "sala2.tscn": 303}


def pick_tile(gx: int, gy: int, grid: list[list[int]], row: list[int], count: int, seed: int) -> int:
    rng = random.Random(seed ^ (gx * 374761) ^ (gy * 668265))
    forbidden = set()
    if gx > 0:
        forbidden.add(row[gx - 1])
    if gy > 0:
        forbidden.add(grid[gy - 1][gx])
    options = [i for i in range(count) if i not in forbidden]
    if not options:
        options = list(range(count))
    return rng.choice(options)


def hash01(gx: int, gy: int, salt: int, seed: int) -> float:
    rng = random.Random(seed ^ (gx * 91203) ^ (gy * 53177) ^ salt)
    return rng.random()


def build_tile_nodes(seed: int) -> tuple[list[str], list[str]]:
    cols = int((AREA_MAX[0] - AREA_MIN[0] + STEP - 1) // STEP)
    rows = int((AREA_MAX[1] - AREA_MIN[1] + STEP - 1) // STEP)
    grid: list[list[int]] = []
    ext_lines: list[str] = []
    node_lines: list[str] = []

    for gy in range(rows):
        row: list[int] = []
        for gx in range(cols):
            row.append(pick_tile(gx, gy, grid, row, len(TEXTURES), seed))
        grid.append(row)

    for gy in range(rows):
        for gx in range(cols):
            idx = grid[gy][gx]
            tid, path = TEXTURES[idx]
            ext_id = f"floor_{tid}"
            ext_line = f'[ext_resource type="Texture2D" path="{path}" id="{ext_id}"]'
            if ext_line not in ext_lines:
                ext_lines.append(ext_line)

            px = AREA_MIN[0] + (gx + 0.5) * STEP
            py = AREA_MIN[1] + (gy + 0.5) * STEP
            bright = 0.92 + hash01(gx, gy, 17, seed) * 0.16
            name = f"Stone_{gx}_{gy}"
            node_lines.append(
                f'\n[node name="{name}" type="Sprite2D" parent="FloorLayer/Floor"]\n'
                f"z_index = -95\n"
                f"position = Vector2({px:.1f}, {py:.1f})\n"
                f"scale = Vector2({TILE_SCALE}, {TILE_SCALE})\n"
                f"texture = ExtResource(\"{ext_id}\")\n"
                f"modulate = Color({bright:.4f}, {bright:.4f}, {bright * 1.02:.4f}, 1)"
            )

    return ext_lines, node_lines


def patch_scene(path: Path, seed: int) -> None:
    text = path.read_text(encoding="utf-8")

    # Remove old baked stone sprites
    text = re.sub(
        r'\n\[node name="Stone_\d+_\d+" type="Sprite2D" parent="World/Hub/Floor"\][\s\S]*?(?=\n\[node name=)',
        "\n",
        text,
    )
    # Remove floor texture ext_resources from prior bake
    text = re.sub(r'\n\[ext_resource type="Texture2D" path="res://assets/floor/pedra_\d\.png" id="floor_pedra_\d"\]', "", text)
    text = re.sub(r'\n\[ext_resource type="Script" path="res://scripts/floor_tiler\.gd" id="floor_tiler"\]', "", text)

    # Hide black backdrop (keep node for bounds if needed)
    text = re.sub(
        r'(\[node name="Backdrop" type="Polygon2D" parent="World/Hub"[^\n]*\n(?:[^\[]*\n)*?)color = Color\([^\)]+\)',
        r"\1visible = false",
        text,
        count=1,
    )

    ext_lines, node_lines = build_tile_nodes(seed)

    # Insert texture ext_resources after gd_scene line block start
    first_ext = text.find("[ext_resource")
    if first_ext == -1:
        raise SystemExit(f"No ext_resource in {path.name}")
    insert_at = first_ext
    text = text[:insert_at] + "\n".join(ext_lines) + "\n" + text[insert_at:]

    # Replace Floor node: no script, baked children after it
    floor_pat = re.compile(
        r'\[node name="Floor" type="Node2D" parent="World/Hub"\][^\[]*',
        re.M,
    )
    floor_header = (
        '[node name="FloorLayer" type="CanvasLayer" parent="."]\n'
        "layer = 125\n"
        "follow_viewport_enabled = true\n\n"
        '[node name="Floor" type="Node2D" parent="FloorLayer"]\n'
        'script = ExtResource("floor_reveal")\n'
        "z_index = -95\n"
    )
    if floor_pat.search(text):
        text = floor_pat.sub(floor_header, text, count=1)
    else:
        marker = "visible = false"
        if marker not in text:
            marker = '[node name="BoundaryGlow"'
        text = text.replace(marker, floor_header + "\n" + marker, 1)

    floor_idx = text.find(floor_header)
    if floor_idx == -1:
        raise SystemExit(f"Floor header missing in {path.name}")
    insert_pos = floor_idx + len(floor_header)
    text = text[:insert_pos] + "".join(node_lines) + text[insert_pos:]

    ext = len(re.findall(r"^\[ext_resource", text, re.M))
    sub = len(re.findall(r"^\[sub_resource", text, re.M))
    text = re.sub(r"load_steps=\d+", f"load_steps={ext + sub + 1}", text, count=1)
    path.write_text(text, encoding="utf-8")
    print(f"{path.name}: baked {len(node_lines)} tiles, seed {seed}")


def main() -> None:
    for name, seed in SEEDS.items():
        patch_scene(SCENES / name, seed)


if __name__ == "__main__":
    main()

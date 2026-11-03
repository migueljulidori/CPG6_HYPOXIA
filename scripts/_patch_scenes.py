#!/usr/bin/env python3
"""Remove polygon obstacles; fill rooms with prop objects; swap HUD node."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCENES = [ROOT / "scenes" / n for n in ("main.tscn", "sala1.tscn", "sala2.tscn")]

PROP_TYPES = [
    ("cadeiras/Azul.png", (34, 34), (2.2, 2.2)),
    ("cadeiras/Laranja.png", (34, 34), (2.2, 2.2)),
    ("cadeiras/Rosa.png", (34, 34), (2.2, 2.2)),
    ("caixas/Azul.png", (40, 40), (2.0, 2.0)),
    ("caixas/Laranja.png", (40, 40), (2.0, 2.0)),
    ("caixas/Rosa.png", (40, 40), (2.0, 2.0)),
    ("mesas/azul.png", (88, 52), (1.55, 1.55)),
    ("mesas/laranja.png", (88, 52), (1.55, 1.55)),
    ("mesas/rosa.png", (88, 52), (1.55, 1.55)),
]

# Grid across playable area (skip center spawn + door lanes)
GRID_X = list(range(-820, 821, 205))
GRID_Y = list(range(-520, 521, 160))
SKIP = {
    (0, 420), (0, 400), (0, 380),
    (-520, 180), (380, -260), (180, 320),
    (980, -40), (918, -8), (-980, 0),
}


def prop_positions():
    out = []
    idx = 0
    for y in GRID_Y:
        for x in GRID_X:
            if abs(x) < 120 and abs(y) < 100:
                continue
            if (x, y) in SKIP:
                continue
            jitter_x = ((idx * 37) % 70) - 35
            jitter_y = ((idx * 53) % 50) - 25
            out.append((x + jitter_x, y + jitter_y))
            idx += 1
    return out


POSITIONS = prop_positions()


def build_props_block() -> str:
    lines = ['[node name="Props" type="Node2D" parent="World/Hub/Obstacles"]', ""]
    for i, (x, y) in enumerate(POSITIONS):
        tex_rel, col, scale = PROP_TYPES[i % len(PROP_TYPES)]
        name = f"Prop{i:02d}"
        tex = f"res://assets/props/{tex_rel}"
        lines += [
            f'[node name="{name}" parent="World/Hub/Obstacles/Props" instance=ExtResource("15_prop")]',
            f"position = Vector2({x}, {y})",
            f'texture_path = "{tex}"',
            f"collision_size = Vector2({col[0]}, {col[1]})",
            f"sprite_scale = Vector2({scale[0]}, {scale[1]})",
            "",
        ]
    return "\n".join(lines)


def remove_section(text: str, start_marker: str, end_marker: str) -> str:
    s = text.find(start_marker)
    if s == -1:
        return text
    e = text.find(end_marker, s)
    if e == -1:
        return text
    return text[:s] + text[e:]


def patch_scene(path: Path) -> None:
    text = path.read_text(encoding="utf-8")

    if "15_prop" not in text:
        text = text.replace(
            "[gd_scene",
            '[ext_resource type="PackedScene" path="res://scenes/prop_obstacle.tscn" id="15_prop"]\n\n[gd_scene',
            1,
        )

    text = remove_section(text, '[node name="InnerWalls"', '[node name="Props"')
    text = remove_section(text, '[node name="Pillars"', '[node name="Props"')

    props_start = text.find('[node name="Props"')
    props_end = text.find('[node name="Gameplay"', props_start)
    if props_start != -1 and props_end != -1:
        text = text[:props_start] + build_props_block() + "\n" + text[props_end:]

    for sub in (
        '[sub_resource type="RectangleShape2D" id="Wall_inner_h"]\n'
        "size = Vector2(360, 36)\n\n",
        '[sub_resource type="RectangleShape2D" id="Pillar_shape"]\n'
        "size = Vector2(48, 120)\n\n",
        '[sub_resource type="RectangleShape2D" id="Crate_shape"]\n'
        "size = Vector2(72, 72)\n\n",
    ):
        text = text.replace(sub, "")

    # HUD: Label -> Control with hud_stats.gd
    hud_old = """[node name="Hint" type="Label" parent="UILayer"]
offset_left = 14.0
offset_top = 12.0
theme_override_colors/font_color = Color(0.85, 0.88, 0.92, 1)
text = "O2: ---"
script = ExtResource("3_hud")"""

    hud_new = """[node name="HUD" type="Control" parent="UILayer"]
layout_mode = 3
anchors_preset = 0
offset_right = 640.0
offset_bottom = 90.0
script = ExtResource("3_hud")"""

    text = text.replace(hud_old, hud_new)

    if 'path="res://scripts/hud_label.gd"' in text:
        text = text.replace(
            'path="res://scripts/hud_label.gd"',
            'path="res://scripts/hud_stats.gd"',
        )

    path.write_text(text, encoding="utf-8")
    print(f"patched {path.name} ({len(POSITIONS)} props)")


if __name__ == "__main__":
    for scene in SCENES:
        patch_scene(scene)

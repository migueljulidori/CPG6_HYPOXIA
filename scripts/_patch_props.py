#!/usr/bin/env python3
"""Inject prop obstacles into hub / sala scenes."""
from pathlib import Path

SCENES = [
    Path(__file__).resolve().parent.parent / "scenes" / name
    for name in ("main.tscn", "sala1.tscn", "sala2.tscn")
]

# Shared layout (hub-sized rooms)
PROPS = [
    ("PropChairA", (630, -90), "res://assets/props/cadeiras/Azul.png", (34, 34), (2.2, 2.2)),
    ("PropBoxB", (-630, 210), "res://assets/props/caixas/Laranja.png", (40, 40), (2.0, 2.0)),
    ("PropTableC", (120, -330), "res://assets/props/mesas/rosa.png", (88, 52), (1.55, 1.55)),
    ("PropBoxD", (-450, -300), "res://assets/props/caixas/Rosa.png", (40, 40), (2.0, 2.0)),
    ("PropChairE", (-180, 40), "res://assets/props/cadeiras/Rosa.png", (34, 34), (2.2, 2.2)),
    ("PropTableF", (220, -480), "res://assets/props/mesas/azul.png", (88, 52), (1.55, 1.55)),
    ("PropBoxG", (-720, -420), "res://assets/props/caixas/Azul.png", (40, 40), (2.0, 2.0)),
    ("PropChairH", (720, 380), "res://assets/props/cadeiras/Laranja.png", (34, 34), (2.2, 2.2)),
    ("PropTableI", (0, 520), "res://assets/props/mesas/laranja.png", (88, 52), (1.55, 1.55)),
    ("PropBoxJ", (-320, 480), "res://assets/props/caixas/Laranja.png", (40, 40), (2.0, 2.0)),
    ("PropChairK", (-520, -180), "res://assets/props/cadeiras/Azul.png", (34, 34), (2.2, 2.2)),
    ("PropTableL", (480, 120), "res://assets/props/mesas/rosa.png", (88, 52), (1.55, 1.55)),
]

MARKER = '[node name="Gameplay" type="Node2D" parent="World/Hub"'


def build_props_block() -> str:
    lines = ['[node name="Props" type="Node2D" parent="World/Hub/Obstacles"]', ""]
    for name, pos, tex, col, scale in PROPS:
        lines.append(
            f'[node name="{name}" parent="World/Hub/Obstacles/Props" instance=ExtResource("15_prop")]'
        )
        lines.append(f"position = Vector2({pos[0]}, {pos[1]})")
        lines.append(f'texture_path = "{tex}"')
        lines.append(f"collision_size = Vector2({col[0]}, {col[1]})")
        lines.append(f"sprite_scale = Vector2({scale[0]}, {scale[1]})")
        lines.append("")
    return "\n".join(lines)


def patch_scene(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    if '[node name="Props" type="Node2D" parent="World/Hub/Obstacles"]' in text:
        print(f"skip (already has Props): {path.name}")
        return
    if "15_prop" not in text:
        insert = '[ext_resource type="PackedScene" path="res://scenes/prop_obstacle.tscn" id="15_prop"]\n'
        text = text.replace("[gd_scene", "[gd_scene", 1)
        idx = text.find("\n", text.find("[gd_scene"))
        text = text[: idx + 1] + insert + text[idx + 1 :]
    idx = text.find(MARKER)
    if idx == -1:
        print(f"WARN: Gameplay marker not found in {path.name}")
        return
    block = build_props_block() + "\n"
    text = text[:idx] + block + text[idx:]
    text = text.replace(
        "[sub_resource type=\"RectangleShape2D\" id=\"Crate_shape\"]\n"
        "size = Vector2(72, 72)\n\n",
        "",
    )
    path.write_text(text, encoding="utf-8")
    print(f"patched {path.name}")


if __name__ == "__main__":
    for scene in SCENES:
        patch_scene(scene)

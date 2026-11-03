#!/usr/bin/env python3
"""Bake organized, functional prop layouts into hub scenes (not random)."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

UNIFORM_SCALE = "Vector2(2.5, 2.5)"
FIT = {
    "mesa": "Vector2(0.72, 0.46)",
    "cadeira": "Vector2(0.56, 0.56)",
    "caixa": "Vector2(0.6, 0.6)",
}


def _p(kind: str, color: str, x: float, y: float) -> tuple[str, str, float, float]:
    return (kind, color, x, y)


HUB_PROPS = [
    _p("mesa", "azul", -500, -200),
    _p("cadeira", "azul", -600, -200),
    _p("cadeira", "laranja", -400, -200),
    _p("cadeira", "rosa", -500, -300),
    _p("cadeira", "azul", -500, -100),
    _p("caixa", "azul", 580, -280),
    _p("caixa", "laranja", 700, -280),
    _p("caixa", "rosa", 580, -160),
    _p("caixa", "laranja", 700, -160),
    _p("caixa", "azul", -750, -40),
    _p("caixa", "rosa", -750, 100),
    _p("caixa", "laranja", -750, 240),
    _p("caixa", "rosa", 560, 60),
    _p("caixa", "azul", 560, 200),
    _p("caixa", "laranja", 560, 340),
    _p("mesa", "laranja", -360, 250),
    _p("mesa", "rosa", 0, 250),
    _p("mesa", "azul", 360, 250),
    _p("cadeira", "laranja", -360, 150),
    _p("cadeira", "rosa", 0, 150),
    _p("cadeira", "azul", 360, 150),
    _p("mesa", "azul", -460, 400),
    _p("cadeira", "azul", -560, 400),
    _p("cadeira", "laranja", -360, 400),
    _p("caixa", "azul", 460, 400),
    _p("caixa", "laranja", 580, 400),
    _p("caixa", "rosa", 520, 500),
    _p("caixa", "azul", -380, -470),
    _p("caixa", "laranja", 380, -470),
    _p("caixa", "rosa", -620, 60),
    _p("mesa", "laranja", 620, -100),
    _p("cadeira", "laranja", 720, -100),
    _p("cadeira", "rosa", 520, -100),
    _p("caixa", "azul", -220, -120),
    _p("mesa", "azul", 80, -300),
    _p("cadeira", "azul", -20, -300),
    _p("cadeira", "laranja", 180, -300),
]

SALA1_PROPS = [
    _p("mesa", "rosa", -480, -180),
    _p("cadeira", "rosa", -580, -180),
    _p("cadeira", "azul", -380, -180),
    _p("cadeira", "laranja", -480, -280),
    _p("caixa", "azul", 580, -300),
    _p("caixa", "laranja", 700, -300),
    _p("caixa", "rosa", 640, -180),
    _p("caixa", "laranja", 700, -60),
    _p("caixa", "azul", -720, -220),
    _p("caixa", "rosa", -720, -80),
    _p("caixa", "laranja", -720, 60),
    _p("mesa", "azul", 320, 80),
    _p("cadeira", "azul", 220, 80),
    _p("cadeira", "laranja", 420, 80),
    _p("mesa", "laranja", -200, 220),
    _p("mesa", "azul", 200, 220),
    _p("cadeira", "laranja", -200, 120),
    _p("cadeira", "azul", 200, 120),
    _p("caixa", "azul", -320, 380),
    _p("caixa", "laranja", -200, 380),
    _p("caixa", "rosa", 400, 360),
    _p("caixa", "azul", 520, 360),
    _p("caixa", "laranja", 460, 460),
    _p("mesa", "rosa", 0, -420),
    _p("cadeira", "rosa", -100, -420),
    _p("cadeira", "azul", 100, -420),
    _p("caixa", "rosa", -500, 40),
    _p("caixa", "azul", 500, -200),
    _p("mesa", "laranja", -80, 80),
    _p("cadeira", "laranja", -180, 80),
]

SALA2_PROPS = [
    _p("mesa", "laranja", 480, -200),
    _p("cadeira", "laranja", 580, -200),
    _p("cadeira", "rosa", 380, -200),
    _p("cadeira", "azul", 480, -300),
    _p("caixa", "azul", -580, -280),
    _p("caixa", "laranja", -700, -280),
    _p("caixa", "rosa", -640, -160),
    _p("caixa", "azul", -700, -40),
    _p("caixa", "rosa", 720, -40),
    _p("caixa", "laranja", 720, 100),
    _p("caixa", "azul", 720, 240),
    _p("mesa", "azul", -320, 80),
    _p("cadeira", "azul", -220, 80),
    _p("cadeira", "laranja", -420, 80),
    _p("mesa", "rosa", -360, 250),
    _p("mesa", "azul", 40, 250),
    _p("mesa", "laranja", 400, 250),
    _p("cadeira", "rosa", -360, 150),
    _p("cadeira", "azul", 40, 150),
    _p("cadeira", "laranja", 400, 150),
    _p("caixa", "azul", -460, 400),
    _p("caixa", "laranja", -340, 400),
    _p("caixa", "rosa", 480, 400),
    _p("caixa", "azul", 600, 400),
    _p("caixa", "laranja", -380, -470),
    _p("caixa", "rosa", 380, -470),
    _p("caixa", "laranja", -500, -120),
    _p("mesa", "rosa", 500, 100),
    _p("cadeira", "rosa", 400, 100),
    _p("caixa", "azul", 0, 80),
]

TERMINALS = {
    "hub": [(-480, 240), (420, -200), (0, 320)],
    "sala1": [(-380, -120), (500, 200), (-200, 360)],
    "sala2": [(360, -140), (-520, 180), (80, 380)],
}

SCENES = {
    "main.tscn": ("hub", HUB_PROPS),
    "sala1.tscn": ("sala1", SALA1_PROPS),
    "sala2.tscn": ("sala2", SALA2_PROPS),
}


def tex_path(kind: str, color: str) -> str:
    if kind == "mesa":
        return f"res://assets/props/mesas/{color}.png"
    if kind == "cadeira":
        c = color if color[0].isupper() else color.capitalize()
        return f"res://assets/props/cadeiras/{c}.png"
    c = color if color[0].isupper() else color.capitalize()
    return f"res://assets/props/caixas/{c}.png"


def build_props_block(props: list[tuple[str, str, float, float]]) -> str:
    lines: list[str] = []
    for i, (kind, color, x, y) in enumerate(props):
        lines.append(
            f'\n[node name="Prop{i:02d}" parent="World/Hub/Obstacles/Props" '
            f'instance=ExtResource("15_prop")]\n'
            f"position = Vector2({x}, {y})\n"
            f'texture_path = "{tex_path(kind, color)}"\n'
            f"sprite_scale = {UNIFORM_SCALE}\n"
            f"collision_fit = {FIT[kind]}\n"
        )
    return "".join(lines)


def bake_scene(path: Path, zone: str, props: list[tuple[str, str, float, float]]) -> None:
    text = path.read_text(encoding="utf-8")
    if 'id="15_prop"' not in text:
        insert = '[ext_resource type="PackedScene" path="res://scenes/prop_obstacle.tscn" id="15_prop"]\n'
        idx = text.find("\n", text.find("[ext_resource"))
        text = text[: idx + 1] + insert + text[idx + 1 :]

    text = re.sub(
        r'\n\[node name="Prop\d+" parent="World/Hub/Obstacles/Props".*?(?=\n\[node |\Z)',
        "",
        text,
        flags=re.DOTALL,
    )

    marker = '[node name="Props" type="Node2D" parent="World/Hub/Obstacles"]'
    if marker not in text:
        raise SystemExit(f"Props node missing in {path.name}")
    text = text.replace(marker, marker + build_props_block(props), 1)

    positions = TERMINALS[zone]
    for i, (x, y) in enumerate(positions):
        name = f"MathTerminal{chr(65 + i)}"
        block = re.search(
            rf'\[node name="{name}"[^\]]*\][\s\S]*?(?=\n\[node )',
            text,
        )
        if block:
            chunk = block.group(0)
            chunk = re.sub(r"\nposition = Vector2\([^\)]+\)", "", chunk)
            chunk = chunk.replace(
                f'[node name="{name}"',
                f'[node name="{name}"',
                1,
            )
            lines = chunk.split("\n")
            lines.insert(1, f"position = Vector2({x}, {y})")
            text = text.replace(block.group(0), "\n".join(lines), 1)

    if "prop_count" in text:
        text = re.sub(r"prop_count = \d+", f"prop_count = {len(props)}", text)
    else:
        text = text.replace(
            f'puzzle_zone = "{zone}"',
            f'puzzle_zone = "{zone}"\nprop_count = {len(props)}',
            1,
        )

    ext = len(re.findall(r"^\[ext_resource", text, re.M))
    sub = len(re.findall(r"^\[sub_resource", text, re.M))
    text = re.sub(r"load_steps=\d+", f"load_steps={ext + sub + 1}", text, count=1)

    path.write_text(text, encoding="utf-8")
    print(f"{path.name}: {len(props)} props, zone={zone}")


def main() -> None:
    for filename, (zone, props) in SCENES.items():
        bake_scene(ROOT / "scenes" / filename, zone, props)


if __name__ == "__main__":
    main()

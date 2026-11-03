#!/usr/bin/env python3
"""Patch hub/sala scenes for function-puzzle mode."""
from __future__ import annotations

import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

HUB_EXT = '[ext_resource type="Script" path="res://scripts/hub_gameplay.gd" id="hub_gameplay"]\n'
PUZZLE_EXT = '[ext_resource type="Script" path="res://scripts/room_function_puzzle.gd" id="room_function_puzzle"]\n'

HUB_NODE = """
[node name="HubGameplay" type="Node2D" parent="World/Hub/Gameplay"]
script = ExtResource("hub_gameplay")
"""

PUZZLE_NODE_TMPL = """
[node name="RoomFunctionPuzzle" type="Node2D" parent="World/Hub/Gameplay"]
script = ExtResource("room_function_puzzle")
sala_id = "{sala_id}"
"""


def _next_id(text: str) -> str:
    ids = [int(m.group(1)) for m in re.finditer(r'id="(\d+)_', text)]
    return str(max(ids, default=20) + 1)


def _inject_ext(text: str, line: str, marker: str) -> str:
    if marker in text:
        return text
    idx = text.find("[ext_resource")
    if idx < 0:
        return line + text
    end = text.find("\n\n", idx)
    if end < 0:
        end = text.find("\n[node", idx)
    insert_at = end if end > 0 else idx
    return text[:insert_at] + "\n" + line + text[insert_at:]


def _fix_load_steps(text: str, added: int) -> str:
    m = re.search(r"load_steps=(\d+)", text)
    if not m:
        return text
    n = int(m.group(1)) + added
    return text[: m.start(1)] + str(n) + text[m.end(1) :]


def patch_hub() -> None:
    path = ROOT / "scenes/main.tscn"
    text = path.read_text(encoding="utf-8")
    if "hub_gameplay" in text:
        print("hub already patched")
        return
    nid = _next_id(text)
    ext = HUB_EXT.replace('id="hub_gameplay"', f'id="{nid}_hub_gameplay"')
    node = HUB_NODE.replace('ExtResource("hub_gameplay")', f'ExtResource("{nid}_hub_gameplay")')
    text = _inject_ext(text, ext, "hub_gameplay.gd")
    text = _fix_load_steps(text, 1)
    anchor = '[node name="Gameplay" type="Node2D" parent="World/Hub"'
    pos = text.find(anchor)
    if pos < 0:
        raise SystemExit("Gameplay node not found in main.tscn")
    line_end = text.find("\n", pos)
    text = text[: line_end + 1] + node.lstrip() + text[line_end + 1 :]
    text = re.sub(
        r'spawn_id = "room1_to_hub"',
        'spawn_id = "sala1_to_hub"',
        text,
    )
    path.write_text(text, encoding="utf-8")
    print("patched main.tscn")


def patch_sala(path: Path, sala_id: str, hub_spawn: str, return_spawn: str) -> None:
    text = path.read_text(encoding="utf-8")
    if "room_function_puzzle" in text:
        print(f"{path.name} already patched")
        return
    nid = _next_id(text)
    ext = PUZZLE_EXT.replace('id="room_function_puzzle"', f'id="{nid}_room_function_puzzle"')
    node = PUZZLE_NODE_TMPL.format(sala_id=sala_id).replace(
        'ExtResource("room_function_puzzle")',
        f'ExtResource("{nid}_room_function_puzzle")',
    )
    text = _inject_ext(text, ext, "room_function_puzzle.gd")
    text = _fix_load_steps(text, 1)
    anchor = '[node name="RoomLayout" type="Node" parent="World/Hub/Gameplay"]'
    pos = text.find(anchor)
    if pos < 0:
        raise SystemExit(f"RoomLayout not found in {path}")
    text = text[:pos] + node.lstrip() + text[pos:]
    text = text.replace('puzzle_zone = "sala1"', f'puzzle_zone = "{sala_id}"', 1)
    text = text.replace('spawn_id = "hub_to_room1"', f'spawn_id = "{hub_spawn}"', 1)
    text = re.sub(
        r'enter_spawn_id = "room1_to_hub"',
        f'enter_spawn_id = "{return_spawn}"',
        text,
    )
    path.write_text(text, encoding="utf-8")
    print(f"patched {path.name}")


def ensure_sala3() -> None:
    src = ROOT / "scenes/sala2.tscn"
    dst = ROOT / "scenes/sala3.tscn"
    if dst.exists():
        return
    shutil.copy(src, dst)
    text = dst.read_text(encoding="utf-8")
    text = text.replace('puzzle_zone = "sala2"', 'puzzle_zone = "sala3"', 1)
    text = text.replace("[gd_scene load_steps=", "[gd_scene load_steps=", 1)
    dst.write_text(text, encoding="utf-8")
    print("created sala3.tscn from sala2")


def main() -> None:
    ensure_sala3()
    patch_hub()
    patch_sala(ROOT / "scenes/sala1.tscn", "sala1", "hub_to_sala1", "sala1_to_hub")
    patch_sala(ROOT / "scenes/sala2.tscn", "sala2", "hub_to_sala2", "sala2_to_hub")
    patch_sala(ROOT / "scenes/sala3.tscn", "sala3", "hub_to_sala3", "sala3_to_hub")


if __name__ == "__main__":
    main()

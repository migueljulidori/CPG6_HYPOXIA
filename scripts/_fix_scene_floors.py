#!/usr/bin/env python3
"""Remove baked floor stones (wrong parent order) and use runtime floor_layer.gd."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCENES = [
	ROOT / "scenes/main.tscn",
	ROOT / "scenes/sala1.tscn",
	ROOT / "scenes/sala2.tscn",
	ROOT / "scenes/sala3.tscn",
]

FLOOR_EXT = '[ext_resource type="Script" path="res://scripts/floor_layer.gd" id="floor_layer"]\n'
FLOOR_CHILD = """
[node name="Floor" type="Node2D" parent="FloorLayer"]
script = ExtResource("floor_layer")
"""


def fix_scene(path: Path) -> None:
	text = path.read_text(encoding="utf-8")
	before = len(text)

	# Glue fix: last stone modulate stuck to BoundaryGlow header.
	text = re.sub(
		r'(modulate = Color\([^\)]+\))\[node name="BoundaryGlow"',
		r'\1\n\n[node name="BoundaryGlow"',
		text,
	)

	# Drop entire misplaced floor block up to BoundaryGlow under World/Hub.
	text = re.sub(
		r'\n\[node name="Floor" type="Node2D" parent="FloorLayer"\][\s\S]*?'
		r'(?=\[node name="BoundaryGlow" type="Node2D" parent="World/Hub")',
		"\n",
		text,
		count=1,
	)

	# Remove baked stone nodes if any remain (safety).
	text = re.sub(
		r'\n\[node name="Stone_\d+_\d+" type="Sprite2D" parent="FloorLayer/Floor"\][\s\S]*?'
		r'(?=\n\[node name=)',
		"",
		text,
	)

	text = re.sub(
		r'\[ext_resource type="Texture2D" path="res://assets/floor/pedra_\d\.png"[^\n]*\n',
		"",
		text,
	)
	text = re.sub(
		r'\[ext_resource type="Script" path="res://scripts/floor_reveal\.gd"[^\n]*\n',
		"",
		text,
	)

	if "floor_layer.gd" not in text:
		pos = text.find("[ext_resource")
		end = text.find("\n\n", pos)
		if end < 0:
			end = text.find("\n[node", pos)
		text = text[:end] + "\n" + FLOOR_EXT + text[end:]

	# Replace any Floor node under FloorLayer with floor_layer script only once at end.
	text = re.sub(
		r'\n\[node name="Floor" type="Node2D" parent="FloorLayer"\][\s\S]*?(?=\n\[node name=)',
		"",
		text,
	)

	floor_layer_block = re.search(
		r'(\[node name="FloorLayer" type="CanvasLayer" parent="\."\]\n'
		r"layer = 125\n"
		r"follow_viewport_enabled = true\n)",
		text,
	)
	if floor_layer_block and 'parent="FloorLayer"' not in text:
		pos = floor_layer_block.end()
		text = text[:pos] + FLOOR_CHILD + text[pos:]

	ext_count = len(re.findall(r"^\[ext_resource", text, re.M))
	sub_count = len(re.findall(r"^\[sub_resource", text, re.M))
	load_steps = ext_count + sub_count + 1
	text = re.sub(r"load_steps=\d+", f"load_steps={load_steps}", text, count=1)

	path.write_text(text, encoding="utf-8")
	stones = len(re.findall(r'Stone_\d+_\d+', text))
	print(f"{path.name}: {before} -> {len(text)} chars, stones_left={stones}, load_steps={load_steps}")


def main() -> None:
	for scene in SCENES:
		if scene.exists():
			fix_scene(scene)


if __name__ == "__main__":
	main()

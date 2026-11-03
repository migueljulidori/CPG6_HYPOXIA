#!/usr/bin/env python3
"""Remove static props; add RoomLayoutRandomizer to each scene."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCENES = {
    "main.tscn": "hub",
    "sala1.tscn": "sala1",
    "sala2.tscn": "sala2",
}

LAYOUT_EXT = '[ext_resource type="Script" path="res://scripts/room_layout_randomizer.gd" id="16_layout"]\n'
LAYOUT_NODE = '''
[node name="RoomLayout" type="Node" parent="World/Hub/Gameplay"]
script = ExtResource("16_layout")
puzzle_zone = "{zone}"
prop_count = 14

'''


def patch(path: Path, zone: str) -> None:
    text = path.read_text(encoding="utf-8")
    if "room_layout_randomizer" in text and "Prop00" not in text:
        print("skip", path.name)
        return
    if 'id="16_layout"' not in text:
        if "[gd_scene" in text:
            first_nl = text.find("\n")
            text = text[: first_nl + 1] + LAYOUT_EXT + text[first_nl + 1 :]
    # Remove all PropXX nodes
    text = re.sub(
        r'\n\[node name="Prop\d+" parent="World/Hub/Obstacles/Props"[\s\S]*?(?=\n\[node name=")',
        "\n",
        text,
    )
    # Strip terminal fixed positions (keep instances)
    for name in ("MathTerminalA", "MathTerminalB", "MathTerminalC"):
        text = re.sub(
            rf'(\[node name="{name}" parent="World/Hub/Gameplay" instance=ExtResource\("8_terminal"\)\])\nposition = Vector2\([^\)]+\)\n',
            r"\1\n",
            text,
        )
        text = re.sub(
            rf'(\[node name="{name}" parent="World/Hub/Gameplay" instance=ExtResource\("8_terminal"\)\])\nposition = Vector2\([^\)]+\)\nterminal_index',
            r"\1\nterminal_index",
            text,
        )
    if '[node name="RoomLayout"' not in text:
        text = text.replace(
            '[node name="Gameplay" type="Node2D" parent="World/Hub"',
            '[node name="Gameplay" type="Node2D" parent="World/Hub"'
            + LAYOUT_NODE.format(zone=zone),
            1,
        )
    path.write_text(text, encoding="utf-8")
    print("patched", path.name)


if __name__ == "__main__":
    for fname, zone in SCENES.items():
        patch(ROOT / "scenes" / fname, zone)

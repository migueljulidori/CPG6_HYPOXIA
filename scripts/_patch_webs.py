#!/usr/bin/env python3
"""Replace Webs block with organized corner + center webs."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Playable inset from walls (~1092, 678)
WEBS = """[node name="Webs" type="Node2D" parent="World/Hub/Gameplay"]

[node name="WebCornerTL" parent="World/Hub/Gameplay/Webs" instance=ExtResource("4_web")]
position = Vector2(-880, -560)
web_kind = "corner"
corner = "top_left"

[node name="WebCornerTR" parent="World/Hub/Gameplay/Webs" instance=ExtResource("4_web")]
position = Vector2(880, -560)
web_kind = "corner"
corner = "top_right"

[node name="WebCornerBL" parent="World/Hub/Gameplay/Webs" instance=ExtResource("4_web")]
position = Vector2(-880, 560)
web_kind = "corner"
corner = "bottom_left"

[node name="WebCornerBR" parent="World/Hub/Gameplay/Webs" instance=ExtResource("4_web")]
position = Vector2(880, 560)
web_kind = "corner"
corner = "bottom_right"

[node name="WebCenter" parent="World/Hub/Gameplay/Webs" instance=ExtResource("4_web")]
position = Vector2(0, 0)
web_kind = "full"

[node name="WebMidL" parent="World/Hub/Gameplay/Webs" instance=ExtResource("4_web")]
position = Vector2(-260, 60)
web_kind = "full"

[node name="WebMidR" parent="World/Hub/Gameplay/Webs" instance=ExtResource("4_web")]
position = Vector2(260, -60)
web_kind = "full"
"""


def patch(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    if 'id="4_web"' not in text and 'web_trap.tscn' in text:
        pass
    if "web_trap.tscn" not in text:
        insert = '[ext_resource type="PackedScene" path="res://scenes/web_trap.tscn" id="4_web"]\n'
        if insert.strip() not in text:
            idx = text.find("\n", text.find("[ext_resource"))
            text = text[: idx + 1] + insert + text[idx + 1 :]

    text = re.sub(
        r'\[node name="Webs" type="Node2D" parent="World/Hub/Gameplay"\][\s\S]*?(?=\n\[node name="(?!Web))',
        WEBS + "\n",
        text,
        count=1,
    )
    if '[node name="Webs"' not in text:
        for anchor in (
            '[node name="Spiders" type="Node2D" parent="World/Hub/Gameplay"',
            '[node name="Rats" type="Node2D" parent="World/Hub/Gameplay"',
            '[node name="RoomLayout" type="Node" parent="World/Hub/Gameplay"',
        ):
            if anchor in text:
                text = text.replace(anchor, WEBS + "\n" + anchor, 1)
                break
        else:
            raise SystemExit(f"No anchor for webs in {path.name}")

    path.write_text(text, encoding="utf-8")
    print("patched", path.name)


def main() -> None:
    for name in ("main.tscn", "sala1.tscn", "sala2.tscn"):
        patch(ROOT / "scenes" / name)


if __name__ == "__main__":
    main()

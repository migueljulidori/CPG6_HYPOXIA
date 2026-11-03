#!/usr/bin/env python3
"""One-off generator for puzzle_bank.gd - run once then delete if desired."""
from pathlib import Path

PUZZLES = {
    "PUZZLES_HUB": [
        ("2, 4, _, 8, 10", "6"), ("15, 12, 9, _, 3", "6"), ("_, 10, 15, 20, 25", "5"),
        ("1, 3, 5, _, 9", "7"), ("10, 20, _, 40, 50", "30"), ("21, 18, _, 12, 9", "15"),
        ("15 + _ = 22", "7"), ("_ * 6 = 42", "7"), ("100 / _ = 25", "4"), ("50 - _ = 14", "36"),
        ("_ + 13 = 30", "17"), ("8 * _ = 64", "8"), ("11, 22, 33, _, 55", "44"),
        ("100, 90, _, 70, 60", "80"), ("7, 14, _, 28, 35", "21"), ("12 + 15 = _", "27"),
        ("30 - _ = 15", "15"), ("_ * 4 = 36", "9"), ("45 / 5 = _", "9"), ("0, 5, _, 15, 20", "10"),
        ("9, 18, _, 36, 45", "27"), ("50 + _ = 100", "50"), ("100 - _ = 1", "99"),
        ("3, 6, _, 12, 15", "9"), ("8, 16, _, 32, 40", "24"),
    ],
    "PUZZLES_SALA1": [
        ("2, 4, 8, 16, _", "32"), ("1, 4, 9, 16, _", "25"), ("1, 2, 4, 7, _, 16", "11"),
        ("3, 6, 12, 24, _", "48"), ("50, 45, 35, 20, _", "0"), ("2, 6, 18, 54, _", "162"),
        ("1, 8, 27, 64, _", "125"), ("5, 15, 45, 135, _", "405"), ("0, 1, 1, 2, 3, _", "5"),
        ("1, 3, 6, 10, _", "15"), ("10, 20, 40, 80, _", "160"), ("128, 64, 32, 16, _", "8"),
        ("2, 5, 11, 23, _", "47"), ("3, 7, 15, 31, _", "63"), ("4, 16, 64, _, 1024", "256"),
        ("1, 5, 25, 125, _", "625"), ("400, 200, 100, 50, _", "25"), ("10, 11, 13, 16, _, 25", "20"),
        ("7, 14, 28, 56, _", "112"), ("5, 11, 23, 47, _", "95"), ("1, 2, 6, 24, _", "120"),
        ("80, 40, 20, 10, _", "5"), ("9, 10, 12, 15, _", "19"), ("20, 22, 26, 34, _", "50"),
        ("6, 12, 24, 48, _", "96"),
    ],
    "PUZZLES_SALA2": [
        ("10, 1, 9, 2, 8, _", "3"), ("1, 100, 2, 200, 3, _", "300"), ("5, 5, 6, 6, 7, _", "7"),
        ("2, 20, 4, 40, 6, _", "60"), ("100, 10, 90, 9, 80, _", "8"), ("1, 2, 3, 5, 8, _", "13"),
        ("1, 99, 2, 98, 3, _", "97"), ("5, 10, 8, 16, 14, _", "28"), ("10, 5, 20, 10, 40, _", "20"),
        ("2, 3, 5, 7, 11, _", "13"), ("3, 1, 6, 2, 9, _", "3"), ("10, 12, 9, 11, 8, _", "10"),
        ("4, 8, 6, 12, 10, _", "20"), ("11, 1, 22, 2, 33, _", "3"), ("50, 5, 40, 4, 30, _", "3"),
        ("1, 4, 3, 16, 5, _", "36"), ("7, 8, 6, 9, 5, _", "10"), ("21, 1, 20, 2, 19, _", "3"),
        ("3, 9, 4, 16, 5, _", "25"), ("10, 100, 11, 121, 12, _", "144"), ("2, 4, 3, 9, 4, _", "16"),
        ("100, 1, 90, 2, 80, _", "3"), ("8, 6, 9, 5, 10, _", "4"),
        ("1, 2, 4, 3, 6, 12, 5, 10, _", "20"), ("2, 5, 4, 10, 6, 15, 8, _", "20"),
    ],
}

lines = [
    "extends Node",
    "## Sequence puzzles per zone.",
    "",
]
for const_name, items in PUZZLES.items():
    lines.append(f"const {const_name}: Array[Dictionary] = [")
    for seq, ans in items:
        lines.append(f'\t{{"sequencia": "{seq}", "resposta": "{ans}"}},')
    lines.append("]")
    lines.append("")

lines += [
    'const ZONE_POOLS: Dictionary = {',
    '\t"hub": PUZZLES_HUB,',
    '\t"sala1": PUZZLES_SALA1,',
    '\t"sala2": PUZZLES_SALA2,',
    "}",
    "",
    "var _used_by_zone: Dictionary = {}",
    "",
    "",
    "func _ready() -> void:",
    "\treset_session()",
    "",
    "",
    "func reset_session() -> void:",
    '\t_used_by_zone = {"hub": [], "sala1": [], "sala2": []}',
    "",
    "",
    "func _puzzle_key(puzzle: Dictionary) -> String:",
    '\treturn str(puzzle.get("sequencia", ""))',
    "",
    "",
    "func _used_list(zone: String) -> Array:",
    "\tif not _used_by_zone.has(zone):",
    '\t\t_used_by_zone[zone] = []',
    "\treturn _used_by_zone[zone]",
    "",
    "",
    'func pick_random(zone: String = "hub") -> Dictionary:',
    "\tvar pool: Array = ZONE_POOLS.get(zone, PUZZLES_HUB)",
    "\tvar used: Array = _used_list(zone)",
    "\tvar available: Array[Dictionary] = []",
    "\tfor puzzle in pool:",
    "\t\tvar key := _puzzle_key(puzzle)",
    "\t\tif key not in used:",
    "\t\t\tavailable.append(puzzle)",
    "\tif available.is_empty():",
    "\t\tavailable = pool.duplicate()",
    "\tvar pick: Dictionary = available[randi() % available.size()].duplicate()",
    "\tused.append(_puzzle_key(pick))",
    "\treturn pick",
    "",
]

Path(__file__).resolve().parent.joinpath("puzzle_bank.gd").write_text("\n".join(lines) + "\n", encoding="utf-8")
print("wrote puzzle_bank.gd")

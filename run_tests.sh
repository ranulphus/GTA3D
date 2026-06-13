#!/usr/bin/env bash
# Run GTA3D headless tests. Override the engine path with GODOT=/path/to/godot.
set -euo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --script res://tests/test_gta1_map.gd

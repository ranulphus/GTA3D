#!/usr/bin/env bash
# Render headless screenshots of the 3D city (offscreen software GL).
# Godot --headless has NO renderer, so we use Xvfb + the OpenGL3 driver.
# Requires: xvfb, mesa software GL (libgl1-mesa-dri). Override engine with GODOT=...
#
#   ./render.sh                 # renders NYC via tests/render_city.gd
#   ./render.sh SANB            # render a different city
set -euo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
xvfb-run -a "$GODOT" --rendering-driver opengl3 --path . \
	--script res://tests/render_city.gd -- "${1:-NYC}"
echo "Screenshots written to _dump/"

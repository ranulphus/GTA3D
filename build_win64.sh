#!/usr/bin/env bash
#
# Build a native Windows x86-64 .exe of GTA3D from Linux (cross-compile via
# Godot's export system). Produces a single self-contained build/GTA3D.exe with
# the game, the GTA1 data files, and the car models embedded.
#
# Usage:
#   ./build_win64.sh                  # release build -> build/GTA3D.exe
#   ./build_win64.sh --debug          # debug build (console output)
#   GODOT=/path/to/godot ./build_win64.sh
#   OUT=dist/MyGame.exe ./build_win64.sh
#
# Requirements: a Godot 4.6 editor binary (GODOT=...), curl + unzip. Matching
# export templates are downloaded automatically the first time (~1 GB).
#
set -euo pipefail

GODOT="${GODOT:-godot}"
GODOT_VERSION="4.6.stable"
PRESET="Windows Desktop"
OUT="${OUT:-build/GTA3D.exe}"
MODE="release"
[[ "${1:-}" == "--debug" ]] && MODE="debug"

cd "$(dirname "$0")"

# --- sanity: engine present ---
if ! command -v "$GODOT" >/dev/null 2>&1 && [[ ! -x "$GODOT" ]]; then
	echo "ERROR: Godot not found. Set GODOT=/path/to/godot (v${GODOT_VERSION%.*})." >&2
	exit 1
fi

# --- ensure export templates are installed ---
TPLDIR="${HOME}/.local/share/godot/export_templates/${GODOT_VERSION}"
if [[ ! -f "${TPLDIR}/windows_release_x86_64.exe" ]]; then
	echo "Windows export templates not found — downloading (~1 GB, one time)…"
	TPZ="$(mktemp /tmp/godot_templates.XXXXXX.tpz)"
	URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION%.*}-${GODOT_VERSION##*.}/Godot_v${GODOT_VERSION%.*}-${GODOT_VERSION##*.}_export_templates.tpz"
	curl -L --retry 3 -o "$TPZ" "$URL"
	mkdir -p "$TPLDIR"
	unzip -o -j "$TPZ" \
		"templates/windows_release_x86_64.exe" \
		"templates/windows_debug_x86_64.exe" \
		"templates/version.txt" -d "$TPLDIR" >/dev/null
	rm -f "$TPZ"
	echo "Installed templates: $(cat "${TPLDIR}/version.txt")"
fi

# --- import resources, then export ---
mkdir -p "$(dirname "$OUT")"
echo "Importing project…"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

echo "Exporting ${MODE} build -> ${OUT}"
if [[ "$MODE" == "debug" ]]; then
	"$GODOT" --headless --path . --export-debug "$PRESET" "$OUT"
else
	"$GODOT" --headless --path . --export-release "$PRESET" "$OUT"
fi

# --- verify ---
if [[ ! -s "$OUT" ]]; then
	echo "ERROR: export produced no output at $OUT" >&2
	exit 1
fi
echo
echo "Built: $OUT"
ls -lh "$OUT" | awk '{print "  size: " $5}'
file "$OUT" | sed 's/^[^:]*: /  type: /'
echo "Copy $OUT to a Windows PC and double-click to play (arrow keys / WASD)."
echo "Note: this build embeds GTA1 data — for personal use, do not redistribute."

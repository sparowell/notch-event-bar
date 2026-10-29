#!/usr/bin/env bash
# Regenerates Supporting/Icon/NotchEventBar.icns from Supporting/Icon/icon.png
# (a 1024x1024 PNG with a transparent background). Uses only sips and iconutil.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICON_DIR="$ROOT/Supporting/Icon"
SRC="$ICON_DIR/icon.png"
OUT="$ICON_DIR/NotchEventBar.icns"
ICONSET="$(mktemp -d)/NotchEventBar.iconset"
mkdir -p "$ICONSET"

render() { sips -z "$1" "$1" "$SRC" --out "$ICONSET/$2" >/dev/null; }
render 16   icon_16x16.png
render 32   icon_16x16@2x.png
render 32   icon_32x32.png
render 64   icon_32x32@2x.png
render 128  icon_128x128.png
render 256  icon_128x128@2x.png
render 256  icon_256x256.png
render 512  icon_256x256@2x.png
render 512  icon_512x512.png
render 1024 icon_512x512@2x.png

iconutil -c icns "$ICONSET" -o "$OUT"
echo "Wrote $OUT"

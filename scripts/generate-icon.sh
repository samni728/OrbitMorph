#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ICONSET="$ROOT_DIR/Resources/OrbitMorph.iconset"
mkdir -p "$ROOT_DIR/Resources"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
swift "$ROOT_DIR/scripts/render-icon.swift" "$ICONSET"
for size in 16 32 128 256 512; do
  sips -s format png -z "$size" "$size" "$ICONSET/icon_1024x1024.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -s format png -z "$double" "$double" "$ICONSET/icon_1024x1024.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$ROOT_DIR/Resources/OrbitMorph.icns"
printf 'Generated %s\n' "$ROOT_DIR/Resources/OrbitMorph.icns"

#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
APP_PATH="${APP_PATH:-$DIST_DIR/OrbitMorph.app}"
DMG_PATH="${DMG_PATH:-$DIST_DIR/OrbitMorph.dmg}"
VOLUME_NAME="${VOLUME_NAME:-OrbitMorph}"
[[ -d "$APP_PATH" ]] || { echo "package-dmg: app bundle missing: $APP_PATH (run scripts/build-app.sh first)" >&2; exit 1; }
command -v hdiutil >/dev/null || { echo 'package-dmg: hdiutil is unavailable.' >&2; exit 1; }
mkdir -p "$(dirname -- "$DMG_PATH")"
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/orbitmorph-dmg-stage.XXXXXX")
TEMP_DMG_DIR=$(mktemp -d "${TMPDIR:-/tmp}/orbitmorph-dmg-output.XXXXXX")
TEMP_DMG="$TEMP_DMG_DIR/OrbitMorph.dmg"
cleanup() { rm -rf "$STAGE" "$TEMP_DMG_DIR"; }
trap cleanup EXIT
/usr/bin/ditto "$APP_PATH" "$STAGE/OrbitMorph.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$VOLUME_NAME" -srcfolder "$STAGE" -ov -format UDZO "$TEMP_DMG"
mkdir -p "$(dirname -- "$DMG_PATH")"
install -m 644 "$TEMP_DMG" "$DMG_PATH"
hdiutil verify "$DMG_PATH"
printf 'Created %s\n' "$DMG_PATH"

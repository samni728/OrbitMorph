#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${APP_PATH:-$ROOT_DIR/dist/OrbitMorph.app}"
DMG_PATH="${DMG_PATH:-$ROOT_DIR/dist/OrbitMorph.dmg}"
EXPECTED_ARCH="${EXPECTED_ARCH:-arm64}"
EXPECTED_VERSION="${EXPECTED_VERSION:-1.2.1}"
MOUNT_POINT=""
REPORT_DIR=$(mktemp -d "${TMPDIR:-/tmp}/orbitmorph-package-report.XXXXXX")

fail() { printf 'verify-package: ERROR: %s\n' "$*" >&2; exit 1; }
cleanup() {
  local status=$?
  trap - EXIT
  if [[ -n "$MOUNT_POINT" ]]; then
    if hdiutil detach "$MOUNT_POINT" -quiet; then
      rmdir "$MOUNT_POINT" || status=1
      MOUNT_POINT=""
    else
      printf 'verify-package: ERROR: failed to detach mount point: %s\n' "$MOUNT_POINT" >&2
      status=1
    fi
  fi
  rm -rf "$REPORT_DIR"
  exit "$status"
}
trap cleanup EXIT

[[ -d "$APP_PATH" ]] || fail "app bundle missing: $APP_PATH"
INFO="$APP_PATH/Contents/Info.plist"
[[ -f "$INFO" ]] || fail "Info.plist missing: $INFO"
BINARY="$APP_PATH/Contents/MacOS/OrbitMorph"
[[ -x "$BINARY" ]] || fail "executable missing: $BINARY"
SOURCE_HASH=$(shasum -a 256 "$BINARY" | awk '{print $1}')

BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO")
MIN_OS=$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$INFO")
AGENT=$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$INFO")
ICON=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$INFO")
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO")
[[ "$BUNDLE_ID" == "com.orbitmorph.app" ]] || fail "unexpected bundle identifier: $BUNDLE_ID"
[[ "$MIN_OS" == "14.0" ]] || fail "minimum macOS version must be 14.0, got $MIN_OS"
[[ "$AGENT" == "true" ]] || fail "LSUIElement must be true"
[[ "$VERSION" == "$EXPECTED_VERSION" ]] || fail "expected version $EXPECTED_VERSION, got $VERSION"
[[ -f "$APP_PATH/Contents/Resources/$ICON" ]] || fail "app icon missing: $ICON"
[[ -f "$APP_PATH/Contents/Resources/Credits.md" ]] || fail "Credits.md missing from app bundle"
ACTUAL_ARCHS=$(lipo -archs "$BINARY")
[[ " $ACTUAL_ARCHS " == *" $EXPECTED_ARCH "* ]] || fail "expected $EXPECTED_ARCH architecture, got: $ACTUAL_ARCHS"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
python3 "$ROOT_DIR/scripts/verify-app-resources.py" "$APP_PATH" > "$REPORT_DIR/source-resources.json"

[[ -f "$DMG_PATH" ]] || fail "DMG missing: $DMG_PATH"
hdiutil verify "$DMG_PATH"
MOUNT_POINT=$(mktemp -d "${TMPDIR:-/tmp}/orbitmorph-dmg.XXXXXX")
hdiutil attach "$DMG_PATH" -readonly -nobrowse -mountpoint "$MOUNT_POINT" -quiet
[[ -d "$MOUNT_POINT/OrbitMorph.app" ]] || fail "DMG does not contain OrbitMorph.app"
[[ -L "$MOUNT_POINT/Applications" ]] || fail "DMG Applications shortcut is missing"
[[ "$(readlink "$MOUNT_POINT/Applications")" == "/Applications" ]] || fail "DMG Applications shortcut points somewhere else"
codesign --verify --deep --strict --verbose=2 "$MOUNT_POINT/OrbitMorph.app"
python3 "$ROOT_DIR/scripts/verify-app-resources.py" "$MOUNT_POINT/OrbitMorph.app" > "$REPORT_DIR/dmg-resources.json"
cmp -s "$REPORT_DIR/source-resources.json" "$REPORT_DIR/dmg-resources.json" || fail "DMG resource content differs from verified app bundle"
DMG_HASH=$(shasum -a 256 "$MOUNT_POINT/OrbitMorph.app/Contents/MacOS/OrbitMorph" | awk '{print $1}')
[[ "$SOURCE_HASH" == "$DMG_HASH" ]] || fail "DMG app executable checksum differs from verified app bundle"
[[ "$(shasum -a 256 "$BINARY" | awk '{print $1}')" == "$SOURCE_HASH" ]] || fail "source app executable changed during package verification"
cmp -s "$INFO" "$MOUNT_POINT/OrbitMorph.app/Contents/Info.plist" || fail "DMG app Info.plist differs from source app"
if ! hdiutil detach "$MOUNT_POINT" -quiet; then fail "failed to detach DMG mount point: $MOUNT_POINT"; fi
rmdir "$MOUNT_POINT"
MOUNT_POINT=""
cat "$REPORT_DIR/source-resources.json"
printf 'verify-package: PASS\n  bundle: %s\n  version: %s\n  arch: %s\n  binary SHA-256: %s\n  DMG: %s\n' "$APP_PATH" "$VERSION" "$ACTUAL_ARCHS" "$SOURCE_HASH" "$DMG_PATH"

#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
APP_PATH="${APP_PATH:-$DIST_DIR/OrbitMorph.app}"
VERSION="${VERSION:-1.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
ARCH="${ARCH:-arm64}"
SCRATCH_PATH="${SCRATCH_PATH:-${TMPDIR:-/tmp}/orbitmorph-task7-release-${UID:-1000}}"

[[ "$(uname -s)" == "Darwin" ]] || { echo 'build-app: macOS is required.' >&2; exit 1; }
command -v swift >/dev/null || { echo 'build-app: Swift 6 toolchain is required.' >&2; exit 1; }
command -v codesign >/dev/null || { echo 'build-app: codesign is unavailable.' >&2; exit 1; }
mkdir -p "$DIST_DIR"
TRIPLE="${ARCH}-apple-macosx14.0"
swift build --package-path "$ROOT_DIR" --configuration release --triple "$TRIPLE" --scratch-path "$SCRATCH_PATH"
BIN_DIR=$(swift build --package-path "$ROOT_DIR" --configuration release --triple "$TRIPLE" --scratch-path "$SCRATCH_PATH" --show-bin-path)
EXECUTABLE="$BIN_DIR/OrbitMorph"
[[ -x "$EXECUTABLE" ]] || { echo "build-app: executable not found: $EXECUTABLE" >&2; exit 1; }

"$ROOT_DIR/scripts/generate-icon.sh"
STAGE=$(mktemp -d "$DIST_DIR/.OrbitMorph-stage.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT
APP="$STAGE/OrbitMorph.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
install -m 755 "$EXECUTABLE" "$APP/Contents/MacOS/OrbitMorph"
install -m 644 "$ROOT_DIR/Resources/OrbitMorph.icns" "$APP/Contents/Resources/OrbitMorph.icns"
install -m 644 "$ROOT_DIR/Resources/Credits.md" "$APP/Contents/Resources/Credits.md"
/usr/libexec/PlistBuddy -c "Print" "$ROOT_DIR/Resources/Info.plist.template" >/dev/null
cp "$ROOT_DIR/Resources/Info.plist.template" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
rm -rf "$APP_PATH"
mv "$APP" "$APP_PATH"
printf 'Built %s (%s, %s)\n' "$APP_PATH" "$ARCH" "$VERSION"

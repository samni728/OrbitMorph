#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${APP_PATH:-$ROOT_DIR/dist/OrbitMorph.app}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/docs/screenshots}"
BINARY="$APP_PATH/Contents/MacOS/OrbitMorph"
[[ "$(uname -s)" == "Darwin" ]] || { echo 'capture-screenshots: macOS is required.' >&2; exit 1; }
[[ -x "$BINARY" ]] || { echo "capture-screenshots: missing app executable: $BINARY (run scripts/build-app.sh)" >&2; exit 1; }
mkdir -p "$OUTPUT_DIR"
"$BINARY" "--render-wheel=$OUTPUT_DIR/wheel.png"
for section in general formats compatibility folders about; do
  "$BINARY" "--render-settings=$OUTPUT_DIR/$section.png" "--section=$section"
done
python3 - "$APP_PATH" "$OUTPUT_DIR" <<'PY'
import datetime
import hashlib
import json
import plistlib
import struct
import sys
from pathlib import Path

app, output = map(Path, sys.argv[1:])
shots = {}
for name in ('wheel', 'general', 'formats', 'compatibility', 'folders', 'about'):
    path = output / f'{name}.png'
    data = path.read_bytes()
    if data[:8] != b'\x89PNG\r\n\x1a\n' or data[12:16] != b'IHDR':
        raise SystemExit(f'Invalid PNG: {path}')
    width, height = struct.unpack('>II', data[16:24])
    expected = (310, 310) if name == 'wheel' else (850, 580)
    if (width, height) != expected:
        raise SystemExit(f'Unexpected size: {path}: {(width, height)}, expected {expected}')
    shots[path.name] = {'width': width, 'height': height, 'sha256': hashlib.sha256(data).hexdigest()}
info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
metadata = {
    'capturedAtUTC': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'version': info['CFBundleShortVersionString'],
    'binarySHA256': hashlib.sha256((app / 'Contents/MacOS/OrbitMorph').read_bytes()).hexdigest(),
    'method': 'Application view self-render; not desktop capture or gesture animation recording',
    'screenshots': shots,
}
(output / 'metadata.json').write_text(json.dumps(metadata, indent=2, ensure_ascii=False) + '\n')
print(f'capture-screenshots: PASS ({len(shots)} PNGs, app {metadata["version"]})')
PY

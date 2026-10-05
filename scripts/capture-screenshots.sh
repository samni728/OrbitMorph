#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${APP_PATH:-$ROOT_DIR/dist/OrbitMorph.app}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/docs/screenshots}"
EXPECTED_VERSION="${EXPECTED_VERSION:-1.2.1}"
BINARY="$APP_PATH/Contents/MacOS/OrbitMorph"
[[ "$(uname -s)" == "Darwin" ]] || { echo 'capture-screenshots: macOS is required.' >&2; exit 1; }
[[ -x "$BINARY" ]] || { echo "capture-screenshots: missing app executable: $BINARY (run scripts/build-app.sh)" >&2; exit 1; }
mkdir -p "$OUTPUT_DIR"
python3 - "$APP_PATH" "$OUTPUT_DIR" "$EXPECTED_VERSION" "$ROOT_DIR/scripts" <<'PY'
import datetime
import hashlib
import json
import plistlib
import subprocess
import sys
import tempfile
from pathlib import Path
from importlib.util import module_from_spec, spec_from_file_location

sys.dont_write_bytecode = True
app, output, expected_version, scripts = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3], Path(sys.argv[4])
spec = spec_from_file_location('resource_validation', scripts / 'verify-app-resources.py')
validation = module_from_spec(spec)
spec.loader.exec_module(validation)
info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
if info['CFBundleShortVersionString'] != expected_version:
    raise SystemExit(f'capture-screenshots: expected app {expected_version}, got {info["CFBundleShortVersionString"]}')
binary = app / 'Contents/MacOS/OrbitMorph'
binary_hash = hashlib.sha256(binary.read_bytes()).hexdigest()
requests = [('wheel.png', 'en', 'wheel', '1'), ('wheel-zh.png', 'zh-Hans', 'wheel', '1'),
            ('wheel-page-2.png', 'en', 'wheel', '2'), ('wheel-page-2-zh.png', 'zh-Hans', 'wheel', '2')]
for language, suffix in [('en', ''), ('zh-Hans', '-zh')]:
    for section in ['general', 'formats', 'compatibility', 'folders', 'about']:
        requests.append((f'{section}{suffix}.png', language, 'settings', section))
requests += [('tutorial-en.png', 'en', 'tutorial', 'conversion'), ('tutorial-zh.png', 'zh-Hans', 'tutorial', 'conversion'),
             ('tutorial-tools-en.png', 'en', 'tutorial', 'tools'), ('tutorial-tools-zh.png', 'zh-Hans', 'tutorial', 'tools')]
shots = {}
with tempfile.TemporaryDirectory(prefix='.OrbitMorph-capture-', dir=output) as staging:
    stage = Path(staging)
    for name, language, surface, section in requests:
        path = stage / name
        arguments = [str(binary), f'--render-{surface}={path}', f'--language={language}', '--appearance=dark', '--style=glass']
        if surface == 'wheel':
            arguments.append(f'--wheel-page={section}')
        elif surface == 'settings':
            arguments.append(f'--section={section}')
        elif surface == 'tutorial':
            arguments.extend([f'--tutorial-step={section}', '--tutorial-preview'])
        result = subprocess.run(arguments, capture_output=True, text=True, timeout=90)
        if result.returncode:
            raise SystemExit(f'capture-screenshots: {name} failed ({result.returncode})\n{result.stdout}\n{result.stderr}')
        dimensions = validation.png_size(path)
        points = {'wheel': (310, 310), 'settings': (850, 580), 'tutorial': (680, 520)}[surface]
        scale = dimensions[0] / points[0]
        if scale not in (1, 2, 3) or dimensions[1] != points[1] * scale:
            raise SystemExit(f'Unexpected screenshot dimensions for {name}: {dimensions}, expected {points} points at 1×, 2× or 3×')
        shots[name] = {'width': dimensions[0], 'height': dimensions[1], 'scale': scale, 'language': language,
                       'surface': surface, 'section': section, 'appearance': 'dark', 'style': 'glass',
                       'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
    # A selected format wheel contains universal file extensions only (e.g. WEBP),
    # so its English and Chinese views may correctly be pixel-identical.
    for english, chinese in [('general.png', 'general-zh.png'), ('tutorial-en.png', 'tutorial-zh.png')]:
        if shots[english]['sha256'] == shots[chinese]['sha256']:
            raise SystemExit(f'Language screenshots are identical: {english}, {chinese}; verify the app really loaded translations')
    for first, second in [('wheel.png', 'wheel-page-2.png'), ('wheel-zh.png', 'wheel-page-2-zh.png')]:
        if shots[first]['sha256'] == shots[second]['sha256']:
            raise SystemExit(f'Wheel pages are identical: {first}, {second}; verify page selection')
    if hashlib.sha256(binary.read_bytes()).hexdigest() != binary_hash:
        raise SystemExit('capture-screenshots: app executable changed during capture')
    metadata = {'capturedAtUTC': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                'version': info['CFBundleShortVersionString'], 'build': info['CFBundleVersion'],
                'binarySHA256': binary_hash,
                'method': 'Final application view self-render through its language-specific CLI; no fabricated UI or desktop/gesture recording',
                'screenshots': shots}
    (stage / 'metadata.json').write_text(json.dumps(metadata, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    for name in [*shots, 'metadata.json']:
        (stage / name).replace(output / name)
print(f'capture-screenshots: PASS ({len(shots)} actual app PNGs, app {metadata["version"]}, English + 简体中文)')
PY

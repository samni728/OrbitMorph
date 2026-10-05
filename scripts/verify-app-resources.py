#!/usr/bin/env python3
"""Validate packaged assets with real parsers; optional converters stay external."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import wave
import zlib


def fail(message):
    raise ValueError(message)


def tool(name):
    configured = os.environ.get(f"{name.upper()}_PATH")
    candidates = [configured, shutil.which(name), f"/opt/homebrew/bin/{name}", f"/usr/local/bin/{name}"]
    for candidate in candidates:
        if candidate and os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return candidate
    fail(f"{name} is required for package verification; install it externally with brew install ffmpeg")


def run(arguments):
    result = subprocess.run(arguments, check=True, capture_output=True, text=True, timeout=60)
    return result.stdout


def png_size(path):
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        fail(f"Not a PNG: {path}")
    offset, dimensions, image_data, ended = 8, None, bytearray(), False
    while offset + 12 <= len(data):
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        end = offset + 12 + length
        if end > len(data):
            fail(f"Truncated PNG chunk: {path}")
        content = data[offset + 8:offset + 8 + length]
        expected = struct.unpack(">I", data[offset + 8 + length:end])[0]
        if zlib.crc32(kind + content) & 0xFFFFFFFF != expected:
            fail(f"Invalid PNG CRC: {path}")
        if kind == b"IHDR":
            if length != 13 or dimensions is not None:
                fail(f"Invalid PNG header: {path}")
            dimensions = struct.unpack(">II", content[:8])
        elif kind == b"IDAT":
            image_data.extend(content)
        elif kind == b"IEND":
            ended = True
            break
        offset = end
    if not dimensions or not ended or not image_data or not zlib.decompress(image_data):
        fail(f"PNG has no readable image data: {path}")
    return dimensions


def language_values(catalogue):
    if catalogue.get("sourceLanguage") != "en" or not isinstance(catalogue.get("strings"), dict):
        fail("Localizable.xcstrings must contain an English sourceLanguage and strings mapping")
    counts = {"en": 0, "zh-Hans": 0}
    for key, entry in catalogue["strings"].items():
        if not isinstance(entry, dict):
            fail(f"Invalid localization entry: {key}")
        translations = entry.get("localizations", {})
        if not isinstance(translations, dict):
            fail(f"Invalid localizations mapping: {key}")
        for language in counts:
            translation = translations.get(language, {})
            if not isinstance(translation, dict) or not isinstance(translation.get("stringUnit", {}), dict):
                fail(f"Invalid translation: {key} ({language})")
            value = translation.get("stringUnit", {}).get("value")
            if isinstance(value, str) and value.strip():
                counts[language] += 1
    if not all(counts.values()):
        fail("Localizable.xcstrings must include nonempty English and Simplified Chinese translations")
    return counts


def verify(app):
    resources = app / "Contents/Resources"
    required = ["OrbitMorph.icns", "Credits.md", "Samples/OrbitMorph-Sample.png",
                "Samples/OrbitMorph-Sample-Video.mp4", "Sounds/segment-tick.wav", "Localizable.xcstrings"]
    for name in required:
        path = resources / name
        if not path.is_file() or path.is_symlink() or not path.stat().st_size:
            fail(f"Required bundled resource missing, empty or linked: {path}")
    icon = (resources / "OrbitMorph.icns").read_bytes()
    if len(icon) < 8 or icon[:4] != b"icns" or struct.unpack(">I", icon[4:8])[0] != len(icon):
        fail("Bundled icon is not a valid ICNS container")
    (resources / "Credits.md").read_text(encoding="utf-8")
    executables = [path.name for path in (app / "Contents/MacOS").iterdir() if path.is_file()]
    if executables != ["OrbitMorph"]:
        fail(f"Unexpected bundled executables: {executables}; external converters must remain external")
    banned = {"ffmpeg", "ffprobe", "magick", "convert", "pandoc", "gs", "7zz", "soffice", "ebook-convert"}
    for path in (app / "Contents").rglob("*"):
        if path.name in banned or path.suffix in {".dylib", ".so", ".a"} or (path.is_dir() and path.suffix == ".app"):
            fail(f"Optional converter/library found inside app bundle: {path}")
    dimensions = png_size(resources / "Samples/OrbitMorph-Sample.png")
    if dimensions != (800, 600):
        fail(f"Unexpected tutorial PNG dimensions: {dimensions}; expected 800×600")
    video = resources / "Samples/OrbitMorph-Sample-Video.mp4"
    probe = json.loads(run([tool("ffprobe"), "-v", "error", "-show_entries",
                            "stream=codec_type,codec_name,width,height:format=format_name,duration:format_tags=major_brand", "-of", "json", str(video)]))
    streams = probe.get("streams", [])
    kinds = {stream.get("codec_type") for stream in streams}
    duration = float(probe.get("format", {}).get("duration", "0"))
    if not {"video", "audio"}.issubset(kinds) or duration <= 0 or "mp4" not in probe.get("format", {}).get("format_name", ""):
        fail("Tutorial MP4 must be an MP4 containing playable audio and video streams")
    if probe.get("format", {}).get("tags", {}).get("major_brand", "").strip() == "qt":
        fail("Tutorial MP4 is a renamed QuickTime MOV rather than an MP4")
    if not any(stream.get("width", 0) > 0 and stream.get("height", 0) > 0 for stream in streams):
        fail("Tutorial MP4 has no video dimensions")
    progress = run([tool("ffmpeg"), "-hide_banner", "-v", "error", "-i", str(video),
                    "-map", "0:v:0", "-map", "0:a:0", "-progress", "pipe:1", "-f", "null", "-"])
    frames = [int(line.split("=", 1)[1]) for line in progress.splitlines() if line.startswith("frame=")]
    if not frames or max(frames) <= 0:
        fail("Tutorial MP4 did not decode any actual video frames")
    with wave.open(str(resources / "Sounds/segment-tick.wav"), "rb") as sound:
        params = sound.getparams()
        samples = sound.readframes(params.nframes)
    if params.comptype != "NONE" or params.nframes <= 0 or params.framerate <= 0 or params.nchannels <= 0:
        fail("Tick WAV must contain playable uncompressed PCM frames")
    if len(samples) != params.nframes * params.nchannels * params.sampwidth:
        fail("Tick WAV sample data is truncated")
    silence = 128 if params.sampwidth == 1 else 0
    if not any(value != silence for value in samples):
        fail("Tick WAV contains only silence")
    counts = language_values(json.loads((resources / "Localizable.xcstrings").read_text(encoding="utf-8")))
    return {
        "files": {name: hashlib.sha256((resources / name).read_bytes()).hexdigest() for name in required},
        "samplePNG": {"width": dimensions[0], "height": dimensions[1]},
        "sampleMP4": {"durationSeconds": duration, "streams": streams, "decodedFrames": max(frames)},
        "tickWAV": {"sampleRate": params.framerate, "channels": params.nchannels,
                    "sampleWidthBytes": params.sampwidth, "frames": params.nframes, "hasAudibleData": True},
        "localizationEntries": counts,
    }


if __name__ == "__main__":
    try:
        if len(sys.argv) != 2:
            fail("usage: verify-app-resources.py /absolute/path/OrbitMorph.app")
        print(json.dumps(verify(Path(sys.argv[1])), ensure_ascii=False, indent=2, sort_keys=True))
    except (ValueError, OSError, subprocess.SubprocessError, wave.Error, zlib.error, struct.error) as error:
        print(f"verify-app-resources: ERROR: {error}", file=sys.stderr)
        raise SystemExit(1)

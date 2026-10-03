# OrbitMorph macOS File Converter — Design Spec

## 1. Product intent
OrbitMorph is a native macOS utility inspired by the interaction demonstrated in `info/ui info.mov` and `info/setting.mov`: a user holds a modifier while dragging one or more files, a translucent radial wheel appears near the pointer, the pointer sweeps across a segment, and releasing the drag selects a conversion or tool. A conventional drop zone and a Settings window provide discoverability and control.

The product is local-first and offline. It should feel like a small system utility, not a browser app.

## 2. Brand
- Name: **OrbitMorph**
- Tagline: **Drop. Spin. Convert.**
- Mark: segmented translucent orbit/ring with a small folded document shape in the center. One warm orange/coral segment indicates the active transformation.
- Avoid copying Tangerine branding, name, icon, or exact artwork.

## 3. Platform and packaging
- Target: Apple Silicon macOS 14+; primary verification machine is the user's Mac M2 on macOS 26.x.
- Native Swift 6 / AppKit / SwiftUI.
- Build through Swift Package Manager, then assemble a normal `.app` bundle with scripts.
- App runs as a menu-bar utility (`LSUIElement`) with no permanent Dock icon.
- Final deliverable includes a repeatable `scripts/build-app.sh` and `scripts/package-dmg.sh`.

## 4. Interaction model
### 4.1 Conversion wheel
- Default trigger: hold **Shift** while dragging a file.
- The first qualifying global drag event opens a non-activating, always-on-top translucent panel centered near the pointer.
- Wheel options are generated from the input format's currently supported targets, up to 8 visible segments. If more targets exist, a second ring/page is allowed later; V1 prioritizes the 8 most useful targets.
- Wheel enters with a 150–220 ms spring/scale/rotation animation: ~0.90 scale and -10° rotation to 1.0/0°.
- Pointer angle determines the highlighted segment. Active segment grows ~6%, receives warm accent, and center label updates.
- Releasing over a valid segment starts conversion. Escape or leaving the active radius cancels.
- Multiple dragged files are accepted when they share at least one target; targets are the intersection of compatible output formats.

### 4.2 Tools wheel
- Default trigger: **Option + Shift** while dragging.
- Same wheel shell but actions instead of output formats.
- V1 tools: Compress, Resize Image, Rotate, Strip Metadata, Extract Audio, Make GIF, PDF Merge (multi-PDF), Archive/Unarchive where applicable.
- Inapplicable tools are not shown.

### 4.3 Drag/drop window
- A compact translucent drop target can be opened from the menu-bar icon.
- Dropping files there opens the same radial wheel in-place so mouse/touchpad behavior is identical to the global path.

### 4.4 Global drag detection
- Observe global mouse-drag and mouse-up events. Modifier state is read from drag events; do not require a normal key chord.
- Prefer the system drag pasteboard (`NSPasteboard.Name.drag`) for file URLs.
- The overlay window registers as a dragging destination, so once it appears it can receive Finder drag URLs directly.
- If the drag pasteboard is not readable at the first global event, the panel still appears only after a file URL is received by `NSDraggingDestination`; never convert an inferred path.
- The app never swallows unrelated drags.

## 5. Visual system
- Panel background: `NSVisualEffectView` / SwiftUI material, clear window, no title bar or shadow-heavy chrome.
- Settings supports **Glass** and **Solid** style, matching the source video's conceptual setting.
- Wheel: 8 wedge layout, subtle hairline borders, center hub, SF Symbols, radial labels.
- Animation uses spring interpolation and opacity; respect Reduce Motion by switching to a short fade/scale without rotation.
- Main accent: orange/coral. Neutral text follows system light/dark appearance.
- Haptic/sound feedback is optional and user-toggleable.

## 6. Settings structure
Replicate the information architecture from the reference video:

### General
- Appearance: Glass / Solid
- Launch at login
- Sound and haptic feedback
- Conversion wheel modifier (default Shift)
- Tools wheel modifier (default Option+Shift)

### Formats
- Sidebar of output formats.
- Per-format defaults. V1 values include image quality, video quality preset, audio bitrate, metadata preservation, and archive compression level when relevant.

### Compatibility
- Matrix grouped into Images, Documents, Audio, Video, Archives.
- Rows are input formats, columns are output formats.
- Cell is enabled only when the conversion registry has a tested backend path.
- User may disable a supported pair; user cannot enable an unsupported pair.

### Folders
- Default: save next to source.
- User can add output folders through `NSOpenPanel` and persist security-scoped bookmarks.
- Optional per-category output folder.

### About
- OrbitMorph mark, version, architecture, local-only statement, dependency diagnostics, licenses/credits.

## 7. Conversion architecture
All conversions go through a `ConversionRegistry` and adapters. UI never builds shell commands.

### 7.1 Images
Primary: ImageMagick when installed at `/opt/homebrew/bin/magick` or common alternatives. Native ImageIO fallback for codecs macOS can encode.
Targets: JPG/JPEG, PNG, WEBP, HEIC/HEIF, TIFF, AVIF, BMP, GIF, PDF (image-to-PDF path).

### 7.2 Video and audio
Primary: FFmpeg/ffprobe discovered from Homebrew/common paths.
Video targets: MP4, MOV, MKV, WEBM, AVI, M4V, GIF.
Audio targets: MP3, M4A/AAC, WAV, FLAC, OGG, OPUS, AIFF.
Video-to-audio is supported where FFmpeg can decode the source.
Use VideoToolbox-compatible defaults when appropriate but favor broad compatibility over maximum speed.

### 7.3 Documents and PDF
- macOS `textutil` for TXT/RTF/HTML/DOC/DOCX/ODT where supported.
- Pandoc for MD/TXT/HTML/DOCX/ODT/RTF transformations that it handles reliably.
- PDFKit/CoreGraphics for PDF page rendering, image-to-PDF, merge/split/rotate.
- Ghostscript may be used for PDF compression/normalization when installed.
- Do not claim arbitrary PDF→DOCX semantic reconstruction; compatibility matrix must remain honest.

### 7.4 Archives
- Native `/usr/bin/ditto`, `/usr/bin/tar`, `/usr/bin/gzip` for ZIP/TAR/TGZ/GZ.
- 7-Zip (`7zz`) for 7Z and supported extraction formats.
- RAR is extraction-only unless a legal/local encoder exists.

## 8. Dependency policy
OrbitMorph V1 is a thin native app that resolves locally installed tools. This avoids silently redistributing GPL/AGPL binaries in the DMG. Dependency Diagnostics shows what is available. The user's current Mac already has FFmpeg, ImageMagick, Pandoc, Ghostscript, 7zz, WebP and libheif via Homebrew.

The app must use absolute resolved binary paths because GUI apps do not inherit the user's shell PATH.

## 9. Data model
Core types:
- `FileKind`: image/document/audio/video/archive/unknown
- `FormatID`: normalized format identifier
- `ConversionRoute`: source, target, backend, default options
- `ToolActionID`: compress/resize/rotate/stripMetadata/extractAudio/makeGIF/pdfMerge/archive/unarchive
- `ConversionJob`: inputs, selected action or target, output directory, options
- `ConversionResult`: outputs, duration, diagnostics
- `AppSettings`: appearance, modifiers, defaults, compatibility overrides, folders

Settings persist to `UserDefaults`; folder bookmarks persist as Data.

## 10. Error handling
- Unknown/unsupported file: wheel does not offer invalid actions; drop window explains unsupported format.
- Missing external dependency: target is disabled and About/Diagnostics identifies the missing command.
- Existing output: append `-converted`, then `-converted-2`, etc.; never overwrite source silently.
- Conversion failure: preserve source, delete incomplete temp output, present concise error and expandable command diagnostics.
- All Process invocations use argument arrays; never shell-interpolate user paths.

## 11. Testing gates
Every implementation slice follows RED→GREEN tests.

Automated tests must cover:
1. format classification and compatibility registry;
2. wheel angle/segment geometry and multi-file target intersection;
3. binary discovery and safe process argument generation;
4. settings persistence/modifier mapping;
5. integration conversions using generated fixtures for image, audio/video, document/PDF, archive;
6. app bundle assembly and Info.plist checks;
7. DMG mount verification.

UI smoke test mode (`--demo-wheel`) opens a deterministic wheel with fixture inputs so the glass/rotation/hover UI can be screenshotted without requiring a Finder drag.

Global Finder drag is additionally instrumented with structured logs; a local drag-source test helper drives an external drag into the overlay when possible. If macOS blocks synthetic cross-process dragging, this limitation is recorded rather than falsely marked automated.

## 12. Acceptance criteria
- `swift test` passes.
- Conversion integration script passes for every compatibility pair marked as V1-tested on this machine.
- `scripts/build-app.sh` creates `dist/OrbitMorph.app` and ad-hoc codesign verification succeeds.
- Launching the app opens a menu-bar item and Settings window on demand.
- Demo wheel visually shows transparent glass, radial layout, entry animation and hover selection.
- Drag/drop window converts a real local fixture to a selected target.
- Shift and Option+Shift global drag pathways are implemented and do not react to unrelated mouse movement.
- `scripts/package-dmg.sh` creates `dist/OrbitMorph.dmg`; it mounts, contains `OrbitMorph.app`, and unmounts cleanly.

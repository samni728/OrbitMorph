# OrbitMorph V1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and package a native macOS file converter whose main interaction is a translucent radial wheel triggered while dragging files with Shift or Option+Shift.

**Architecture:** A SwiftPM macOS executable hosts AppKit windows and SwiftUI content. A pure Swift core owns format classification, compatibility, settings, wheel geometry and jobs; backend adapters execute native APIs or resolved command-line converters. A non-activating overlay panel receives external file drags and renders the radial wheel.

**Tech Stack:** Swift 6, AppKit, SwiftUI, PDFKit, ImageIO, UniformTypeIdentifiers, XCTest, FFmpeg, ImageMagick, Pandoc/textutil, Ghostscript, 7zz/ditto/tar, shell packaging scripts.

**Spec:** `docs/superpowers/specs/2026-10-03-orbitmorph-design.md`

## Global Constraints
- Target Apple Silicon macOS 14+; verify on the user's Mac M2.
- Brand is OrbitMorph; do not copy Tangerine branding/artwork.
- Never overwrite source files silently.
- GUI process resolves absolute binary paths; do not rely on shell PATH.
- Process arguments are arrays; never shell-interpolate file paths.
- Compatibility UI exposes only routes that are genuinely implemented/tested.
- Global triggers: Shift = conversion wheel; Option+Shift = tools wheel.

## Review Focus
- Filenames containing spaces/quotes/unicode must convert without command injection or path corruption.
- Mixed multi-file drags must expose only the intersection of compatible targets.
- Missing Homebrew converters must disable affected routes instead of crashing.
- Existing destination names must create a collision-safe new name.
- Reduce Motion and Solid appearance must not break wheel selection geometry.

---

### Task 1: Core package, formats, compatibility and dependency discovery
**Files:** `Package.swift`, `Sources/OrbitMorphCore/*`, `Tests/OrbitMorphCoreTests/CoreRegistryTests.swift`
**Produces:** `FormatID`, `FileKind`, `ConversionRoute`, `DependencyResolver`, `ConversionRegistry`, `OutputNamer`.

- [x] Write failing tests for extension normalization, category classification, route filtering, mixed-file target intersection, missing dependency disabling, and collision-safe naming.
- [x] Run `swift test --filter CoreRegistryTests` and confirm RED.
- [x] Implement the minimal core types/registry/resolver/namer.
- [x] Run filtered tests and full `swift test`; both GREEN.
- [ ] Commit `feat: add conversion registry core`.

### Task 2: Wheel geometry and settings model
**Files:** `Sources/OrbitMorphCore/WheelGeometry.swift`, `Sources/OrbitMorphCore/AppSettings.swift`, `Tests/OrbitMorphCoreTests/WheelSettingsTests.swift`
**Produces:** deterministic wedge calculation, modifier matching, Codable/UserDefaults settings schema.

- [x] Write failing tests for 8-segment angle mapping, dead-zone/outside radius, Shift vs Option+Shift precedence, format overrides and settings roundtrip.
- [x] Verify RED.
- [x] Implement geometry/settings.
- [x] Run filtered + full suite GREEN.
- [ ] Commit `feat: add wheel geometry and settings`.

### Task 3: Conversion engine and tested backend adapters
**Files:** `Sources/OrbitMorphCore/ProcessRunner.swift`, `ConversionEngine.swift`, `Adapters/*.swift`, `Tests/OrbitMorphCoreTests/ConversionIntegrationTests.swift`, `Tests/Fixtures/*`.
**Produces:** async `ConversionEngine.convert(job:)`, safe process execution, image/media/document/archive adapters.

- [x] Create generated fixture strategy and failing integration tests for image, media, document/PDF and archive routes plus unicode/space paths.
- [x] Verify RED because adapters do not exist.
- [x] Implement adapters using discovered absolute tools and native APIs where practical.
- [x] Run integration tests, fixing only routes whose output can be validated by file signature/ffprobe/text/archive listing.
- [x] Generate the V1 tested compatibility table from passing routes; run full suite GREEN.
- [ ] Commit `feat: add local conversion backends`.

### Task 4: Radial glass UI and deterministic demo mode
**Files:** `Sources/OrbitMorphApp/Views/RadialWheelView.swift`, `WheelViewModel.swift`, `OverlayPanelController.swift`, `DropWindowController.swift`, `OrbitMorphMain.swift`, `Tests/OrbitMorphCoreTests/WheelPresentationTests.swift`.
**Produces:** glass/solid radial wheel, spring entry rotation, hover highlight, center label, drop window, `--demo-wheel` mode.

- [x] Write failing presentation-state tests for visible segment ordering, selected index, cancel state and reduce-motion animation parameters.
- [x] Verify RED.
- [x] Implement the SwiftUI wheel and AppKit transparent non-activating panel/drop window.
- [x] Run tests GREEN and build executable.
- [x] Launch `--demo-wheel`, capture a screenshot, verify transparent radial layout exists visually.
- [ ] Commit `feat: add radial glass conversion wheel`.

### Task 5: Global drag modifiers and conversion orchestration
**Files:** `Sources/OrbitMorphApp/GlobalDragMonitor.swift`, `DragPasteboardReader.swift`, `JobCoordinator.swift`, `Tests/OrbitMorphCoreTests/DragLogicTests.swift`.
**Produces:** global mouse-drag recognition, modifier routing, drag URL validation, drop-to-job flow, progress/result notifications.

- [x] Write failing tests for event state machine: unrelated move ignored, Shift conversion, Option+Shift tools precedence, cancel on mouse-up without drop, validated file URLs only.
- [x] Verify RED.
- [x] Implement global monitor and dragging destination bridge without swallowing unrelated events.
- [x] Run unit/full suite GREEN.
- [x] Launch app and exercise an internal/external drag harness into the overlay; inspect logs for expected state transitions.
- [ ] Commit `feat: add global drag wheel workflow`.

### Task 6: Menu bar and Settings replica
**Files:** `Sources/OrbitMorphApp/AppDelegate.swift`, `SettingsWindowController.swift`, `Views/Settings/*.swift`, `Sources/OrbitMorphCore/FolderBookmarks.swift`, tests.
**Produces:** General/Formats/Compatibility/Folders/About tabs, status item actions, diagnostics, folder bookmark persistence.

- [x] Write failing tests for settings tab data sources, compatibility override guard, folder bookmark model and dependency diagnostics.
- [x] Verify RED.
- [x] Implement menu bar and five Settings sections using source-video information architecture.
- [x] Run tests/build GREEN.
- [x] Launch Settings and capture screenshots of General, Compatibility and About for visual inspection.
- [ ] Commit `feat: add OrbitMorph settings and menu bar`.

### Task 7: Brand assets, app bundle and DMG packaging
**Files:** `Resources/OrbitMorphMark.svg`, `scripts/generate-icon.sh`, `scripts/build-app.sh`, `scripts/package-dmg.sh`, `scripts/verify-package.sh`, `Resources/Info.plist.template`.
**Produces:** branded app icon, `dist/OrbitMorph.app`, `dist/OrbitMorph.dmg`.

- [x] Write packaging verification script first; run it and confirm RED because bundle is absent.
- [x] Add OrbitMorph vector mark/icon generation and app bundle assembly.
- [x] Build app, ad-hoc sign, run verification GREEN.
- [x] Add DMG creation; mount/read/unmount verification GREEN.
- [ ] Commit `build: package OrbitMorph app and dmg`.

### Task 8: End-to-end verification and polish
**Files:** README, generated compatibility report, any fixes with regression tests.
**Produces:** reproducible build/test evidence and usable V1 artifact.

- [x] Run fresh `swift test` full suite.
- [x] Run conversion matrix integration tests and save report.
- [x] Run app/demo/settings smoke scripts and packaging verification.
- [x] Review code against spec and fix Critical/Important findings with RED→GREEN regression tests.
- [ ] Run all verification again from clean build; record exact outputs/limitations.
- [ ] Commit `chore: finalize OrbitMorph v1 verification`.

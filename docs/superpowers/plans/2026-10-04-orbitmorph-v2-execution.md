> 历史设计：其中 Drop Window、Show Tutorial 和真实样本转换要求已由 1.2.1 用户反馈撤销。当前行为见 `docs/USER_GUIDE.md`（仓库根目录）：仅一次性内部教学，无投放入口。

# OrbitMorph V2 Implementation Plan

> 本文件保留最初 V2 计划。2026-10-04 收尾沿用此 UI/教程方案；用户随后授权的常用格式扩展以 `2026-10-04-common-format-gaps.md` 为准，包括 LibreOffice、Calibre 和 Vision OCR，因此下方旧依赖范围已被后续需求更新。当前完成度与最终验收证据见 `../../verification/开发进度.md`，下方原始执行清单不作为发布状态。

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a new OrbitMorph build where normal launches stay menu-bar-only, first-run onboarding teaches the real Shift / Option+Shift drag gestures using bundled sample files, the wheel has stronger translucent glass plus subtle segment audio feedback, localization supports English/简体中文, and SVG/WMV/WMA/SRT/VTT are integrated and tested.

**Architecture:** Preserve the existing SwiftPM + AppKit + SwiftUI structure. Add explicit onboarding/localization services rather than overloading `DropWindowController`; keep `GlobalDragMonitor` as the single source of drag gesture events and let onboarding observe those events. Extend `FormatID`/registry minimally for new formats and preserve the existing atomic output/real-conversion validation pipeline.

**Tech Stack:** Swift 6, AppKit, SwiftUI, AVFoundation, ImageIO/PDFKit, FFmpeg, ImageMagick, XCTest, shell packaging scripts.

**Spec:** `docs/superpowers/specs/2026-10-03-orbitmorph-v2-onboarding-localization-formats-design.md`

## Global Constraints
- Target Apple Silicon macOS 14+.
- Normal launch must not automatically open `DropWindow` after onboarding is completed.
- Tutorial window must be closable/movable and closing or skipping must suppress future automatic display.
- Existing menu-bar commands and conversion safety guarantees must remain available.
- Sample files must be bundled locally and use the real drag pipeline.
- Wheel glass must remain readable with Reduce Transparency / Increase Contrast.
- Segment audio is subtle, rate-limited, and obeys the existing Sound & haptic feedback setting.
- Do not add LibreOffice/qpdf/Inkscape/Calibre/OCRmyPDF dependencies in this release.
- Existing valid conversion routes must not regress.

## Review Focus
- A completed user relaunches the app: no desktop window appears, menu bar remains usable.
- First-run tutorial close/skip cannot trap the user in a repeated-launch loop.
- Hovering rapidly across wheel segments cannot produce overlapping/loud audio spam.
- Custom modifier settings still drive tutorial instructions and completion detection correctly.
- Missing FFmpeg/ImageMagick capabilities hide new routes instead of advertising broken conversions.

---

### Task 1: Fix launch lifecycle and onboarding persistence

**Files:**
- Create: `Sources/OrbitMorphCore/OnboardingState.swift`
- Create: `Tests/OrbitMorphCoreTests/OnboardingStateTests.swift`
- Modify: `Sources/OrbitMorphCore/AppSettings.swift`
- Modify: `Sources/OrbitMorphApp/AppDelegate.swift`

**Interfaces:**
- Produces `OnboardingState.currentVersion`, `shouldAutoPresent(settings:)`, `markCompleted(settings:)`.
- `AppDelegate` uses this decision instead of unconditional `drop.show()`.

- [ ] Write tests proving legacy V1 settings auto-present once, completed settings do not auto-present, and skip/complete persist.
- [ ] Run the filtered tests and confirm RED.
- [ ] Implement the minimal onboarding persistence and migrate old settings without losing existing values.
- [ ] Add an app-level startup policy test proving completed launch does not request Drop Window presentation.
- [ ] Run filtered and full tests GREEN.

### Task 2: Build first-run tutorial with real sample drag sources

**Files:**
- Create: `Sources/OrbitMorphApp/TutorialWindowController.swift`
- Create: `Sources/OrbitMorphApp/Views/TutorialView.swift`
- Create: `Sources/OrbitMorphApp/SampleDragSourceView.swift`
- Create: `Resources/Samples/OrbitMorph-Sample.png`
- Create: `Resources/Samples/OrbitMorph-Sample-Video.mp4`
- Modify: `Sources/OrbitMorphApp/AppDelegate.swift`
- Modify: `Sources/OrbitMorphApp/GlobalDragMonitor.swift`
- Modify: `Sources/OrbitMorphApp/OverlayPanelController.swift`
- Test: `Tests/OrbitMorphAppTests/TutorialWorkflowTests.swift`

**Interfaces:**
- `GlobalDragMonitor` emits gesture activation/drop events without changing normal drag behavior.
- Tutorial consumes events only when the dragged URL matches a bundled sample.

- [ ] Write failing workflow tests for Step 1 conversion sample, Step 2 tools sample, skip, close, reopen-from-menu.
- [ ] Run tests and confirm RED.
- [ ] Generate small original PNG and H.264/AAC MP4 resources.
- [ ] Implement movable/closable tutorial window with Back/Skip/Next and four steps.
- [ ] Implement AppKit drag source so sample URLs enter the real NSPasteboard drag path.
- [ ] Wire `Show Tutorial` into the status menu; keep `Open Drop Window` manual-only.
- [ ] Run workflow and full tests GREEN.

### Task 3: Strengthen wheel glass and add subtle segment sound

**Files:**
- Modify: `Sources/OrbitMorphApp/DragReceivingView.swift`
- Modify: `Sources/OrbitMorphApp/Views/RadialWheelView.swift`
- Create: `Sources/OrbitMorphApp/WheelFeedbackController.swift`
- Test: `Tests/OrbitMorphAppTests/WheelFeedbackTests.swift`

**Interfaces:**
- `WheelFeedbackController.selectionChanged(to: Int?, enabled: Bool)` rate-limits one soft tick per distinct segment.
- No sound fires for repeated updates inside the same segment or when feedback is disabled.

- [ ] Write failing tests for distinct-segment sound triggering, same-segment suppression, disabled setting, and minimum debounce interval.
- [ ] Run tests and confirm RED.
- [ ] Implement feedback using a bundled/system short sound with low volume and no overlap.
- [ ] Increase glass transparency of the wheel outer segments while preserving text contrast and center clarity.
- [ ] Add stronger edge highlight/gap rather than opaque gray fills; respect Reduce Transparency.
- [ ] Run tests and render a wheel snapshot for visual inspection.

### Task 4: Refresh Settings/Tutorial glass treatment

**Files:**
- Create: `Sources/OrbitMorphApp/Views/GlassCard.swift`
- Modify: `Sources/OrbitMorphApp/Views/SettingsView.swift`
- Modify: `Sources/OrbitMorphApp/SettingsWindowController.swift`
- Modify: `Sources/OrbitMorphApp/Views/TutorialView.swift`
- Test: `Tests/OrbitMorphAppTests/GlassPresentationTests.swift`

**Interfaces:**
- `GlassCard` centralizes card fill, border, corner radius, contrast fallback.

- [ ] Write presentation tests for glass/solid and accessibility fallback state.
- [ ] Run tests RED.
- [ ] Implement common glass card/background treatment without changing sidebar/menu information architecture.
- [ ] Render Light/Dark settings/tutorial snapshots and inspect readability.
- [ ] Run tests GREEN.

### Task 5: Add English / 简体中文 localization

**Files:**
- Create: `Sources/OrbitMorphApp/LocalizationManager.swift`
- Create: `Resources/Localizable.xcstrings`
- Modify: `Sources/OrbitMorphCore/AppSettings.swift`
- Modify: `Sources/OrbitMorphApp/AppState.swift`
- Modify: `Sources/OrbitMorphApp/AppDelegate.swift`
- Modify: `Sources/OrbitMorphApp/Views/SettingsView.swift`
- Modify: `Sources/OrbitMorphApp/Views/TutorialView.swift`
- Test: `Tests/OrbitMorphAppTests/LocalizationTests.swift`

**Interfaces:**
- Language values: `system`, `en`, `zh-Hans`.
- Menu/UI strings resolve through one localization service.

- [ ] Write failing tests for English, Simplified Chinese, system fallback, menu title and tutorial text.
- [ ] Run tests RED.
- [ ] Implement localization manager and settings migration.
- [ ] Add General language picker and runtime refresh/rebuild of menu strings.
- [ ] Run tests GREEN and snapshot English/Chinese tutorial/settings.

### Task 6: Add SVG / WMV / WMA / SRT / VTT

**Files:**
- Modify: `Sources/OrbitMorphCore/Formats.swift`
- Modify: `Sources/OrbitMorphCore/ConversionRegistry.swift`
- Modify: `Sources/OrbitMorphCore/Adapters/FFmpegAdapter.swift`
- Create: `Sources/OrbitMorphCore/Adapters/SubtitleAdapter.swift`
- Modify: `Sources/OrbitMorphCore/ConversionEngine.swift`
- Test: `Tests/OrbitMorphCoreTests/V2FormatTests.swift`
- Modify: `Tests/OrbitMorphCoreTests/ConversionMatrixTests.swift`

**Interfaces:**
- New `FormatID`: `.svg`, `.wmv`, `.wma`, `.srt`, `.vtt`.
- SRT/VTT use a native lightweight subtitle adapter; FFmpeg/ImageMagick routes remain capability-gated.

- [ ] Write failing format classification/route tests.
- [ ] Run tests RED.
- [ ] Implement format IDs and category handling.
- [ ] Implement SRT↔VTT adapter with timestamp/header validation.
- [ ] Extend FFmpeg capability probing for WMV/WMA target encoders and ImageMagick SVG input availability.
- [ ] Run real conversions: SVG→PNG, WMV→MP4, WMA→MP3, SRT→VTT, VTT→SRT, plus reverse WMV/WMA targets when encoders exist.
- [ ] Run the full conversion matrix and require zero advertised-route failures.

### Task 7: Bundle resources and update package verification

**Files:**
- Modify: `scripts/build-app.sh`
- Modify: `scripts/verify-package.sh`
- Modify: `README.md`
- Modify: `docs/verification/开发进度.md`

**Interfaces:**
- App bundle must contain Samples and localization resources.

- [ ] Write package checks for sample PNG/MP4 and localization resources; confirm RED against old package.
- [ ] Update bundle assembly to copy resources.
- [ ] Build release app and run verification GREEN.
- [ ] Package DMG and verify mount/signature/hash/symlink/resources.

### Task 8: Final regression and install new build

**Files:**
- No new product files unless a regression fix requires one and a RED test is added first.

- [ ] Run `swift test` from a clean scratch build.
- [ ] Run full conversion matrix.
- [ ] Run `git diff --check`.
- [ ] Launch a reset-onboarding build and confirm tutorial appears once.
- [ ] Complete/skip tutorial, relaunch, and confirm no desktop window appears.
- [ ] Manually open Drop Window and Show Tutorial from menu bar.
- [ ] Verify wheel glass snapshot and segment sound behavior.
- [ ] Install the verified `dist/OrbitMorph.app` to `/Applications` and confirm binary hash matches the dist build.
- [ ] Record final version/checksums and remaining limitations.

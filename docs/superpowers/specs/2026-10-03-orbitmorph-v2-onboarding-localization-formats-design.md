> 历史设计：其中 Drop Window、Show Tutorial 和真实样本转换要求已由 1.2.1 用户反馈撤销。当前行为见 `docs/USER_GUIDE.md`（仓库根目录）：仅一次性内部教学，无投放入口。

# OrbitMorph V2 Onboarding / Localization / Format Expansion Design

## 1. Goal

在现有 OrbitMorph V1 上完成一次不推倒重做的 V2 产品体验升级，解决当前每次启动都会常驻 Drop Window 的问题，并对齐参考录屏中的首次安装引导逻辑。同时增加中英文切换、增强玻璃材质，并补齐一批无需新增重型依赖即可支持的格式。

本轮范围固定为：

- 正常启动不再自动展示桌面常驻窗口。
- 首次启动进入一次性 onboarding。
- onboarding 使用内置 PNG sample 与 MP4 sample，引导用户完成 Shift / Option+Shift 两种拖拽手势。
- onboarding 完成或主动 Skip 后，后续启动仅保留菜单栏图标。
- 菜单栏可以重新打开 Tutorial 和 Drop Window。
- Settings / Tutorial / Wheel 增强玻璃层次，但保留原信息架构。
- 增加 System / English / 简体中文。
- 新增 SVG / WMV / WMA / SRT / VTT。
- 保留现有转换、安全、打包和测试体系。

不在本轮引入 LibreOffice、qpdf、Inkscape、OCRmyPDF、Calibre 等大型新依赖；这些继续作为后续 Backend Pack 路线。

---

## 2. Current Problem

### 2.1 Drop Window 常驻的根因

当前 `AppDelegate.applicationDidFinishLaunching` 正常启动分支会：

1. 设置 accessory activation policy；
2. 创建菜单栏；
3. 创建 `DropWindowController`；
4. 启动全局拖拽监控；
5. 在没有 `--settings` 参数时直接调用 `drop.show()`。

因此每次正常启动都会打开 Drop Window。该行为不是系统限制，而是代码明确指定的启动行为。

### 2.2 当前 Drop Window 与参考录屏的定位不同

现有 Drop Window 是一个长期工具窗口：

- 显示 `Drop. Spin. Convert.`；
- 接收普通拖放；
- 没有 onboarding 状态；
- 没有教程完成状态；
- 没有 sample 文件；
- 没有步骤进度；
- 没有首次启动限定。

参考录屏中的窗口则是一次性教程：

- Step 1：使用 sample 图片练习 Shift + drag；
- Step 2：使用 sample 视频练习 Option + Shift + drag；
- Step 3：输出位置 / 权限说明；
- Step 4：Ready，进入菜单栏常驻状态。

因此 V2 应把“教程窗口”和“日常 Drop Window”拆成两个不同产品概念。

---

## 3. Startup State Machine

新增独立的 onboarding 状态，不再通过“是否显示 Drop Window”隐式表达首次启动。

建议持久化字段：

```text
onboardingVersion: Int
onboardingCompletedVersion: Int
preferredLanguage: system | en | zh-Hans
```

当前教程版本设为 `1`。

### 3.1 首次启动

```text
App launch
  ↓
menu bar ready
  ↓
start drag monitor
  ↓
onboardingCompletedVersion < onboardingVersion ?
  ├─ yes → show Tutorial Window
  └─ no  → remain menu-bar only
```

### 3.2 完成教程

当用户完成最后一步：

```text
onboardingCompletedVersion = onboardingVersion
close tutorial
remain menu-bar only
```

### 3.3 Skip

用户在任意步骤点击 Skip：

- 明确提示“以后可从菜单栏 Show Tutorial 再次打开”；
- 将当前 onboarding 标记为完成；
- 关闭 Tutorial；
- 不再自动弹出。

### 3.4 关闭窗口

Tutorial 使用正常 `.titled + .closable` 窗口，可移动、可关闭。

关闭按钮行为与 Skip 一致，避免用户关闭后下一次启动又被强制弹出。

### 3.5 菜单栏

菜单新增：

```text
Open Drop Window
Show Tutorial
Convert Files…
Reveal Last Outputs
Settings…
About OrbitMorph
Quit OrbitMorph
```

`Open Drop Window` 继续提供当前的普通拖放工具。

`Show Tutorial` 始终可用，即便 onboarding 已完成。

---

## 4. Onboarding UX

### 4.1 Tutorial Window

建议窗口尺寸约 680×520，可拖动、可关闭。

结构：

```text
┌──────────────────────────────────────────────┐
│ OrbitMorph                    Step 1 of 4    │
│                                              │
│              Hold. Drag. Drop.               │
│   Hold Shift while dragging a file.          │
│                                              │
│        [ PNG Sample Preview ]                │
│        Drag this sample →                    │
│                                              │
│  Back                     Skip      Next      │
└──────────────────────────────────────────────┘
```

### 4.2 Step 1 — Conversion Wheel

内置一个 PNG sample，例如：

```text
OrbitMorph-Sample.png
```

要求：

- 清晰可见的缩略图；
- 用户可以直接从 tutorial 内把 sample 拖出去；
- 文案提示：按住 Shift 拖动；
- 当全局拖拽监控检测到 sample 文件 + conversion mode 时，step 进入 active；
- 当文件真正被 drop 到某个格式扇区后，step 标记 completed；
- 用户可看到“Done”反馈，并允许 Next。

注意：不要求 sample 一定成功转换成某个特定格式；成功完成 conversion wheel 的拖拽选择行为即可视为教程完成。若转换执行失败，应显示正常错误，但教程仍可依据手势完成情况决定是否通过。

### 4.3 Step 2 — Tools Wheel

内置一个短 MP4 sample，例如：

```text
OrbitMorph-Sample-Video.mp4
```

要求：

- 3–5 秒、低码率、无版权问题；
- 体积尽量小；
- 用户按住 Option + Shift 拖动；
- 正确出现 Tools Wheel；
- 真正 drop 到任一可用工具后标记完成。

建议 sample 至少包含一条音轨，确保 `Extract Audio` 等工具可演示。

### 4.4 Step 3 — Output Location

展示当前默认逻辑：

```text
Save beside source file
```

并提供：

- 保持默认；
- 打开 Folders Settings；
- 简短说明文件不会上传云端。

本轮不强制 Home Folder 权限作为教程完成条件。

### 4.5 Step 4 — Ready

显示：

- OrbitMorph 已驻留菜单栏；
- Shift = Convert；
- Option + Shift = Tools；
- 可从菜单栏重新打开 Tutorial / Settings；
- `Let's get started` 完成教程并关闭窗口。

---

## 5. Sample Files

### 5.1 PNG Sample

资源路径：

```text
Resources/Samples/OrbitMorph-Sample.png
```

要求：

- 800×600 左右；
- 视觉简单但可识别；
- 原创；
- 无第三方 Logo；
- 文件体积小；
- 可用于 JPG / WEBP / HEIC / PDF 等演示。

### 5.2 Video Sample

资源路径：

```text
Resources/Samples/OrbitMorph-Sample-Video.mp4
```

要求：

- 3–5 秒；
- H.264 + AAC；
- 640×360 或相近尺寸；
- 原创纯色/几何动画即可；
- 含音轨；
- 目标是教程，不是展示视频质量。

### 5.3 Drag Source

Tutorial 不能只放一个静态图片预览。

需要实现一个真正的 AppKit/SwiftUI drag source，向 NSPasteboard 写入 sample 文件 URL，使它与 Finder 拖动文件走同一套 global drag / overlay / drop pipeline。

这样教程测试的是“真实产品交互”，而不是单独做一套假的 demo。

---

## 6. Glass Visual Refresh

### 6.1 保持不变

以下信息架构不变：

- Settings 左侧导航位置；
- General / Formats / Compatibility / Folders / About；
- Wheel 环形交互；
- OrbitMorph 橙色品牌强调色。

### 6.2 Settings

目标：从“大面积纯白 + 灰色卡片”升级为更轻、更有层次的 macOS 材质。

建议：

- Window 背景使用系统 visual effect；
- Sidebar 采用稳定、稍高不透明度的系统材质；
- 内容区域背景允许适度透出后方色彩；
- Card 使用统一 `GlassCard` 组件；
- 边界主要依靠材质、圆角和轻微 highlight，不使用过重灰色矩形；
- 保证 Light / Dark Mode 都可读。

### 6.3 Tutorial

Tutorial 是本轮玻璃体验重点：

- 外层窗口透明；
- 主内容是大面积柔和 blur；
- sample 卡片可以有更明显的玻璃边缘；
- 当前 step 和按钮层级高于背景；
- 保留足够文字对比度。

### 6.4 Wheel

Wheel 继续使用 NSVisualEffectView 背景，但进一步统一：

- 未选中扇区降低实色感；
- 扇区间用 gap + highlight 分隔；
- 选中扇区保留橙色，但增加轻微 scale；
- 中心显示更多上下文，例如：

```text
3 Files
→ WEBP
```

- Reduce Motion 开启时禁止旋转，只保留淡入/轻微缩放；
- Reduce Transparency 开启时自动提升不透明度，不牺牲可读性。

---

## 7. Localization

### 7.1 Supported Locales

本轮支持：

```text
System Default
English (en)
简体中文 (zh-Hans)
```

### 7.2 Resource Strategy

使用 String Catalog：

```text
Resources/Localizable.xcstrings
```

统一覆盖：

- Menu Bar；
- Tutorial；
- Drop Window；
- Settings；
- Tool labels；
- Status messages；
- Errors / Alerts；
- About / Diagnostics。

格式名和工具品牌不翻译：

- JPG / PNG / MP4；
- FFmpeg / ImageMagick；
- OrbitMorph。

### 7.3 Runtime Language Switching

General 增加 Language picker。

用户切换后：

- SwiftUI 界面立即刷新；
- menu bar 重新 build；
- 后续 Alert 使用新语言；
- 不要求重启。

如果 AppKit 部分无法完全无重启刷新，最低可接受标准是：Settings/Tutorial 立即更新，菜单栏下一次展开前重建。

### 7.4 Localization Architecture

不要把语言判断散落在 View 内。

建议：

```text
LocalizationManager
  ├─ selectedLanguage
  ├─ locale
  ├─ string(key)
  └─ languageDidChange
```

AppState 持有或引用 LocalizationManager，但不直接包含所有文案。

---

## 8. Format Expansion

本轮只新增现有工具栈能可靠支持的格式，避免安装新大型 Backend。

### 8.1 SVG

新增：

```text
SVG
```

主要 Backend：ImageMagick。

首批支持路线建议：

```text
SVG → PNG
SVG → JPG
SVG → WEBP
SVG → PDF
```

如当前 ImageMagick 构建实际支持 SVG 读取，则路线启用；若 delegate 缺失则 Capability Registry 不应暴露该路线。

### 8.2 WMV

新增：

```text
WMV
```

Backend：FFmpeg。

建议：

```text
WMV → MP4 / MOV / MKV / WEBM / AVI / M4V / GIF
WMV → MP3 / M4A / WAV / FLAC / OGG / OPUS
常见视频格式 → WMV
```

只有当前 FFmpeg build 存在可用 WMV encoder 时才允许作为 target。

### 8.3 WMA

新增：

```text
WMA
```

Backend：FFmpeg。

建议：

```text
WMA → MP3 / M4A / AAC / WAV / FLAC / OGG / OPUS / AIFF
常见音频格式 → WMA
```

目标格式同样需要 encoder capability probe。

### 8.4 SRT / VTT

新增：

```text
SRT
VTT
```

定位为 Subtitle category，不混入 Document。

首批：

```text
SRT ↔ VTT
```

Backend 优先使用 FFmpeg 或一个轻量原生文本转换器。

建议优先实现原生文本 converter：

- SRT → VTT：时间戳和 header 转换；
- VTT → SRT：序号 + 时间戳转换；
- 不需要启动 FFmpeg；
- 易测、快、无额外依赖。

同时可为视频增加“Extract Subtitles”作为后续工具，但不属于本轮必做。

### 8.5 FileKind

新增：

```text
subtitle
vector（可选）
```

为控制本轮复杂度，SVG 可以先归 `image`；SRT/VTT 必须单独归 `subtitle`，避免进入 textutil / Pandoc 文档路线。

### 8.6 Compatibility Matrix

新增格式后 Compatibility Settings 必须自动反映实际 capability。

不得为了 UI 看起来完整而显示无法通过真实输出测试的路线。

---

## 9. Architecture Changes

本轮不进行完整 BackendRegistry 大重构，但应为后续重构预留边界。

### 9.1 OnboardingManager

新增独立对象：

```text
OnboardingManager
  currentVersion
  completedVersion
  currentStep
  markGestureCompleted(...)
  finish()
  skip()
  reset()
```

不要把 onboarding 状态直接塞进 `DropWindowController`。

### 9.2 TutorialWindowController

新增：

```text
TutorialWindowController
TutorialView
SampleDragSource
```

它与 `DropWindowController` 相互独立。

### 9.3 Drag Completion Events

当前 GlobalDragMonitor / Overlay 主要负责显示与 drop。

需要增加无侵入事件：

```text
onGestureActivated(mode, files)
onWheelDrop(mode, selectedItem, files)
```

OnboardingManager 订阅这些事件，只观察 tutorial sample 文件，不影响正常用户拖拽。

### 9.4 App Lifecycle

AppDelegate 负责：

- menu bar；
- drag monitor；
- 根据 onboarding 状态决定是否显示 tutorial；
- 不再默认 `drop.show()`。

### 9.5 Settings Model Migration

AppSettings 增加：

```text
language
onboardingCompletedVersion
```

Decode 必须继续兼容旧 V1 settings，缺失字段时使用默认值。

不要因为 schema 增加导致现有用户设置丢失。

---

## 10. Error / Edge Cases

### Tutorial sample 不存在

如果 bundle sample 资源损坏：

- tutorial 显示友好错误；
- Skip 仍可用；
- App 主功能不受影响。

### 用户关闭 Tutorial

视为 Skip，避免下次重启再次打扰。

### 用户未按正确 modifier

- 普通拖动 sample 不完成 step；
- UI 提示正确组合；
- 不弹错误 Alert。

### 用户切换自定义 shortcut

Tutorial 文案和完成条件必须读取当前实际 settings，而不是硬编码 Shift / Option+Shift。

但首版 sample 标题可显示默认推荐键位。

### 多显示器

Wheel 继续使用当前 mouse location 与屏幕判断逻辑；tutorial 窗口可移动，不固定桌面中央。

### Accessibility

- Reduce Motion；
- Reduce Transparency；
- Increase Contrast；
- VoiceOver label；
- 键盘可操作的 Next / Back / Skip。

---

## 11. Testing Strategy

### 11.1 Onboarding Unit Tests

必须覆盖：

- V1 用户没有 onboarding 字段时首次显示；
- 完成后下次启动不显示；
- Skip 后不再显示；
- Show Tutorial 可以强制重新打开；
- tutorial version 升级后可以重新显示；
- Step 1 只接受正确 sample + conversion mode；
- Step 2 只接受正确 sample + tools mode。

### 11.2 Startup Tests

验证：

- 正常已完成用户启动时 Drop Window 不自动 show；
- 菜单栏存在；
- `Open Drop Window` 手动可打开；
- `Show Tutorial` 手动可打开。

### 11.3 Localization Tests

覆盖：

- English；
- zh-Hans；
- System fallback；
- 菜单项；
- Settings section；
- Tutorial；
- 至少一个 error message。

### 11.4 New Format Tests

每个新格式必须有真实输出验证：

- SVG → PNG；
- WMV → MP4；
- MP4 → WMV（仅当前 encoder 可用时）；
- WMA → MP3；
- MP3 → WMA（仅 encoder 可用时）；
- SRT → VTT；
- VTT → SRT。

继续加入全矩阵测试，不允许只验证文件扩展名。

### 11.5 UI Snapshot / Smoke

至少输出：

- Tutorial Step 1 English；
- Tutorial Step 2 中文；
- Settings General Glass；
- Wheel Glass；
- Dark Mode 至少一张。

### 11.6 Packaging

沿用：

```text
scripts/build-app.sh
scripts/package-dmg.sh
scripts/verify-package.sh
```

并新增检查 sample 和 localization resources 确实进入 app bundle。

---

## 12. Acceptance Criteria

V2 只有同时满足以下条件才视为完成：

1. 新安装 / reset onboarding 后第一次启动出现 Tutorial。
2. Tutorial 窗口可以拖动、关闭、Skip。
3. Step 1 sample PNG 可以真实拖动并触发 Conversion Wheel。
4. Step 2 sample MP4 可以真实拖动并触发 Tools Wheel。
5. 完成或 Skip 后，重新启动不再自动出现任何桌面窗口。
6. 日常启动只显示 menu bar icon。
7. 菜单栏 `Open Drop Window` 仍能手动打开原拖放窗口。
8. 菜单栏 `Show Tutorial` 可重新打开教程。
9. Settings / Tutorial / Wheel 的玻璃视觉明显强于 V1，同时 Light/Dark 可读。
10. System / English / 简体中文可以切换，关键界面全部生效。
11. SVG / WMV / WMA / SRT / VTT 出现在正确类别和兼容矩阵。
12. 新格式路线全部通过真实转换测试。
13. 原有 253 路或其更新后的有效路线矩阵无回归。
14. 所有 XCTest 通过。
15. 新 `.app` / `.dmg` 构建、签名校验、DMG 挂载校验通过。

---

## 13. Out of Scope

本轮明确不做：

- LibreOffice / XLSX / PPTX；
- qpdf 深度 PDF 工具；
- OCRmyPDF / Tesseract OCR UI；
- Calibre / EPUB；
- Inkscape 专业 SVG backend；
- 完整 Backend Plugin SDK；
- Developer ID notarization；
- Windows / Linux 版本。

这些在 V2 本轮稳定后再进入下一阶段。

---

## 14. Implementation Principle

本轮最重要的产品原则不是“再加一个窗口”，而是：

> Tutorial 只属于第一次学习阶段；OrbitMorph 日常状态应该尽可能隐形，常驻菜单栏，只有在用户拖文件并按快捷键时才出现。

这与参考录屏的交互定位一致，也是本次改造的核心验收标准。

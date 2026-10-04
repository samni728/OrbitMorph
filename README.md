<p align="center"><img src="Resources/OrbitMorph.iconset/icon_128x128@2x.png" width="112" alt="OrbitMorph app icon"></p>

# OrbitMorph

**Drop. Spin. Convert. — 拖动文件，转盘选择，本地转换。**

OrbitMorph 是一个面向 Apple Silicon 的原生 macOS 文件转换工具。按住快捷键拖动 Finder 文件，唤出磨砂玻璃转盘，滑向目标格式后松开即可转换。SwiftUI 与 AppKit 构建界面，系统框架和本机开源转换器处理文件。

**当前版本：1.1.0（V1 + 格式扩展）。** 已有 V2 引导、本地化与更多后端的设计文档；规划与实际支持能力分开记录。

## 界面预览

<p align="center"><img src="docs/screenshots/wheel.png" width="310" alt="OrbitMorph radial conversion wheel"></p>

转盘演示模式展示分区、橙色高亮和中心提示；真实文件只显示共同可用目标。截图由实际应用渲染；透明浮窗的桌面模糊与入场动画需在运行中体验。

![General 设置](docs/screenshots/general.png)

| 格式参数 | 格式兼容矩阵 |
| --- | --- |
| ![Formats](docs/screenshots/formats.png) | ![Compatibility](docs/screenshots/compatibility.png) |

| 输出目录 | 本机转换器诊断 |
| --- | --- |
| ![Folders](docs/screenshots/folders.png) | ![About](docs/screenshots/about.png) |

[完整截图与重新生成方法](docs/screenshots/README.md)

## 核心功能

- **快捷键转盘**：Shift 打开格式转换，Option + Shift 打开工具；General 可修改组合。
- **原生玻璃**：背景磨砂、圆角分区、旋转与弹簧缩放入场、悬停高亮、淡出退场，支持系统 Reduce Motion。
- **多文件转换**：显示共同可用目标；超过八个目标可滚轮或点击 More 翻页。
- **设置实际生效**：质量、音频码率、适用的编码预设、压缩级别、元数据、禁用路线与输出目录。
- **原文件保留**：临时转换后排他提交；重名添加序号，批次失败清理本批次产物。
- **本地处理**：没有账号、服务器或文件上传；About 可检查已安装转换器。

## 支持格式

本轮补齐 **SVG、WMV、WMA、SRT、VTT**。格式识别不等于任意两种格式都能互转，路线由转换器、编码器与兼容设置决定。

| 类别 | 当前识别格式 | 能力与边界 |
| --- | --- | --- |
| 图片 | JPG、PNG、WEBP、HEIC、TIFF、AVIF、BMP、GIF、SVG | 常规图片互转；SVG 先输入转 PNG/JPG/WEBP/PDF，不提供栅格图矢量化 |
| 文档 | PDF、DOC、DOCX、TXT、MD、RTF、HTML、ODT | Pandoc/textutil 的实际路线；PDF 原生逐页转 JPG/PNG，无 PDF → DOCX/OCR |
| 音频 | MP3、M4A、AAC、WAV、FLAC、OGG、OPUS、AIFF、WMA | FFmpeg；WMA 与 OGG 按编码能力过滤，传统目标依赖常见 FFmpeg 构建 |
| 视频 | MP4、MOV、MKV、WEBM、AVI、M4V、WMV | 视频互转、GIF、音频抽取；WMV 输出探测实际能力，抽音频要求有音轨 |
| 归档 | ZIP、7Z、TAR、TGZ、GZ、RAR | 输出 ZIP/7Z/TAR/TGZ；GZ/RAR 仅输入，不提供 RAR 编码 |
| 字幕 | SRT、VTT | 原生双向转换，保留常见字幕文本和时间，不依赖 FFmpeg |

[逐条转换路线报告](docs/verification/转换路线验收.md) · [机器可读结果](docs/verification/conversion-matrix.json) · [格式缺口与后续优先级](docs/FORMAT_COVERAGE.md)

本机安装工具组合的验收数量不代表每台 Mac 的固定可用数量。

## 快速开始

需要 **Apple Silicon、macOS 14+、Swift 6 工具链**，主要在 Mac M2 上验证。

```sh
git clone https://github.com/samni728/OrbitMorph.git
cd OrbitMorph

# 可选：补齐常用媒体、图片、文档与归档能力
brew install ffmpeg imagemagick pandoc sevenzip ghostscript

swift run OrbitMorph
```

不安装可选工具也能启动；ImageIO、PDFKit、textutil、ditto、tar 提供部分原生能力。应用检查 Homebrew 标准路径及系统路径，不自动下载或安装依赖。

### 日常使用

1. 在 Finder 开始拖动文件，持续按住 **Shift**。
2. 转盘出现后移到目标分区，松开鼠标生成新文件。
3. **Option + Shift** 使用工具转盘，动作按文件类别和依赖显示。
4. 也可把文件拖入 Drop Window 后点击目标，或用菜单栏 **Convert Files…**。

释放快捷键、移出后松开或按 Escape 可取消。默认输出位于源文件旁；目录在 **Settings → Folders** 配置，分类按输入类型，例如视频抽音频使用 Video。

当前普通启动会打开 Drop Window；仅菜单栏启动和首次教程仍是 V2 规划。

## 构建 app 与 DMG

```sh
scripts/build-app.sh
scripts/capture-screenshots.sh
scripts/package-dmg.sh
scripts/verify-package.sh
```

结果在 `dist/OrbitMorph.app` 和 `dist/OrbitMorph.dmg`，不纳入 Git。打开 DMG 可将应用拖入 Applications。

脚本支持 `VERSION`、`BUILD_NUMBER`、`ARCH`、`SCRATCH_PATH`、`DIST_DIR` 覆盖项；默认 arm64/macOS 14+。当前是本地 **ad-hoc 签名**，未做 Developer ID 签名、公证，也未随包分发 FFmpeg 等工具。

## 测试与开发

```sh
swift test

# 需要完整本机工具组合，生成夹具并逐条转换、解析产物
ORBITMORPH_FULL_MATRIX=1 swift test

scripts/verify-package.sh
git diff --check
```

常规测试默认跳过全路线矩阵；显式开启后验证图片、媒体流、文档文本、归档根内容及字幕。RAR 使用 [libarchive 官方夹具](https://github.com/libarchive/libarchive/blob/master/libarchive/test/test_read_format_rar5_stored.rar.uu)。

2026-10-04 本机最终验收：**85 个测试全部通过，294 条注册路线逐条转换通过，0 失败、0 未覆盖**。其中新增五个格式带来 41 条路线；截图、ARM64 构建和 DMG 校验也已通过。

GUI 接收器/状态机测试不等同真实 Finder 快捷键手势验收，后者仍需人工体验确认。[开发进度与验收边界](docs/verification/开发进度.md)

## 代码结构

```text
Sources/OrbitMorphApp/   窗口、菜单栏、设置、转盘、系统拖拽与任务反馈
Sources/OrbitMorphCore/  格式、路线、任务、输出提交与后端 adapters
Tests/                  单元、回归、真实转换及界面接收器测试
Resources/              原创图标、Info.plist、工具许可说明
scripts/                构建、打包、验证、截图
docs/                   使用、架构、格式覆盖、规划与验证证据
info/                   原项目提供的 UI / Setting 参考录屏
```

[详细使用说明](docs/USER_GUIDE.md) · [架构与开发](docs/DEVELOPMENT.md) · [原始设计](docs/superpowers/specs/2026-10-03-orbitmorph-design.md) · [V2 规划](docs/superpowers/specs/2026-10-03-orbitmorph-v2-onboarding-localization-formats-design.md)

## 当前边界与下一步

- PDF 转图逐页输出；静态图片目标及 ImageIO 后备只取动画首帧。
- 无音轨视频抽音频会明确失败；复杂文档版式受转换器能力影响。
- 字幕独有的样式、位置或元信息不能保证互相保留。
- 当前字幕只转换基础 UTF-8 cue；VTT 的 STYLE/REGION 和 cue 布局 settings 会明确拒绝，NOTE 注释忽略。
- ExFAT 排他复制回退尚未经过真实 ExFAT 卷验收。
- 未接入 LibreOffice、Calibre、OCR 等后端，不能宣称 Office、电子书和扫描文档完整互转。
- Next 优先：首次引导、中英文、进度/取消、内容级媒体过滤；更多格式按场景逐批接入并验收。

## 品牌与外部工具

OrbitMorph 是原创轨道与折角文档标记；参考录屏用于交互研究，项目使用自己的名称和品牌。

转换器独立安装，适用各自许可，见 [Credits](Resources/Credits.md)。仓库当前未指定统一项目开源许可证；源码托管不等同于已经授予某种开源许可。

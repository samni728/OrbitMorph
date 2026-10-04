# OrbitMorph 产品经理评审与 V2 建议

> 文档定位：供产品与技术团队评审、拆分后续任务使用。本文只提出产品与架构建议，不包含代码修改。
>
> 当前项目基线：OrbitMorph V1 已具备 Finder 拖拽、Shift / Option+Shift 转盘、Settings、格式转换、253 条本机实测转换路线、ARM64 App/DMG 等完整闭环。

---

## 1. 结论摘要

OrbitMorph 当前已经是一个“可以使用”的 macOS 文件转换工具，但与最初参考录屏中希望复刻的产品体验相比，仍有三个明显差距：

1. **视觉层次还偏传统 macOS 设置面板**，玻璃、悬浮、背景透视和空间层级感不足；尤其 Settings 内容区和转盘扇区目前仍较“实”，没有形成强烈的 Apple 式材质感。
2. **缺少完整的国际化体系**，目前主要用户界面为英文，后续如果继续扩展功能，越晚做本地化改造，硬编码字符串和错误文案的迁移成本越高。
3. **格式数量看起来不少，但“格式家族”仍不够完整**。当前图片/音视频/基础文档/压缩已经覆盖较好，真正缺的是 Office 表格和演示文稿、电子书、矢量图、OCR、专业图像、PDF 深度工具、结构化数据等高价值场景。

从产品经理角度，不建议下一阶段单纯追求“路线数量继续翻倍”。更合理的路线是：

> **先把核心交互做到像一个真正的 Mac 原生工具，再把转换后端改成可扩展架构，最后按格式家族逐层增加能力。**

建议 V2 的产品目标定义为：

> **OrbitMorph = 一个以 Finder 拖甩转盘为核心交互、具有 Apple 原生玻璃视觉、支持中英文、按需聚合本地开源转换引擎的 macOS Universal File Converter。**

---

# 2. 与原始参考录屏的主要差距

## 2.1 当前已经完成的核心能力

当前版本已经完成以下关键能力，因此不建议推倒重做：

- Finder 文件拖动触发。
- Shift = 格式转换转盘。
- Option + Shift = 文件工具转盘。
- 环形分区、hover、高亮、旋转与弹簧动画。
- Glass / Solid 两种外观模式。
- General / Formats / Compatibility / Folders / About 设置页面。
- 多文件格式交集判断。
- 本地转换，不上传云端。
- 多后端转换：FFmpeg、ImageMagick、Pandoc、ImageIO、PDFKit、7zz、ditto、tar 等。
- 真实文件转换矩阵测试。

这些是很好的产品基础。

## 2.2 当前最明显的体验差距

原始参考录屏的核心产品感，更接近：

> **“Finder 上方临时浮出的系统级工具层”**

而目前 OrbitMorph 在视觉上更容易被理解成：

> **“一个传统设置 App + 一个环形转换弹窗”**

技术逻辑已经接近，但产品感觉仍有距离。

重点不是增加更多按钮，而是强化：

- 背景透视；
- 浮层深度；
- 毛玻璃材质；
- 控件与内容分层；
- 文件正在经过转盘“被转换”的即时感；
- 快捷键按下、进入扇区、松手确认之间的连续反馈。

---

# 3. UI / 玻璃质感建议

## 3.1 产品原则

用户要求保持菜单位置不变，这个方向是正确的。

建议：

- **左侧导航栏位置、信息架构不变。**
- 重点修改窗口背景、内容卡片、分隔线、转盘扇区、按钮的材质表现。
- 不要为了“玻璃”把所有组件都做成玻璃。

Apple 当前设计原则同样强调，Liquid Glass 更适合作为控制和导航的功能层，而内容区域应保持清晰层次，避免整个界面全部透明导致视觉噪声。

参考：
- Apple HIG Materials: https://developer.apple.com/design/human-interface-guidelines/materials
- NSVisualEffectView: https://developer.apple.com/documentation/appkit/nsvisualeffectview

## 3.2 当前 UI 的问题

从现有截图看：

### Settings

目前 General / Formats / Compatibility / Folders 页面存在以下问题：

- 大面积纯白背景占比高；
- 卡片多为浅灰实色；
- Sidebar 与内容层之间主要靠直线分隔；
- 控件虽然干净，但缺少“背景穿透”和“材质层级”；
- 整体像系统偏好设置的传统版本，而不是新的轻量悬浮工具。

### Wheel

目前转盘结构是正确的，但视觉上：

- 未选中扇区偏实色；
- 背景内容穿透不足；
- 中心层与外环材质差异不明显；
- hover 主要靠橙色填充，缺少玻璃边缘、光泽和景深反馈。

## 3.3 建议采用“三层材质体系”

### Layer A：窗口 / Overlay 基础层

用途：提供环境模糊和背景透视。

建议：

- 继续使用 `NSVisualEffectView`；
- 根据位置使用 `.sidebar` / `.popover` / `.hudWindow` 等语义材质；
- `blendingMode` 根据 Settings 和浮层场景分别使用 `.withinWindow` / `.behindWindow`；
- 窗口本身尽可能减少实色背景。

产品目标：

> 用户应该还能感知桌面、Finder 或后方窗口的颜色变化，而不是看到一个纯白面板。

### Layer B：内容卡片层

General、Formats、Folders 里的卡片不要再使用明显的灰底矩形。

建议设计：

- 半透明卡片；
- 轻微背景 blur；
- 细微 1px 高光边；
- 很弱的 inner highlight；
- 更大的圆角；
- 阴影只用于层级，不做明显浮雕。

视觉目标可以先用设计稿尝试：

- Card 填充视觉透明度约 20%–35%；
- Border 白色或系统高光约 10%–20%；
- Shadow 透明度很低；
- Sidebar 的材质比内容卡片更稳定、更不透明，以保证导航易读。

注意：上述数字是设计参考，不建议直接写死。最终实现应优先使用系统 Material，并遵守 Reduce Transparency / Increase Contrast。

### Layer C：交互控件层

按钮、Toggle、Picker、Wheel 当前选中分区属于“功能层”。

建议：

- 使用更明显的玻璃或系统控件材质；
- 橙色仍作为 OrbitMorph 品牌强调色；
- 橙色只出现在当前选择、确认动作、状态反馈，不要铺满界面。

## 3.4 转盘建议重点优化

### 未选中扇区

当前灰色可以进一步透明。

建议：

- 每个扇区类似独立玻璃片；
- 能透出 Finder 背景；
- 边缘有细微亮边；
- 相邻扇区不要依赖深灰线分割，而更多依靠材质和间隙。

### 选中扇区

当前橙色填充方向可以保留，但建议增加：

- 轻微放大 1.02–1.05；
- 高光从边缘向中心移动；
- 图标 / 格式文字同步增强；
- 中心区域即时更新目标；
- 有条件可增加非常弱的 haptic / sound feedback。

### 中心区域

建议从现在的“标签中心”升级为：

- 当前目标；
- 当前源文件类型；
- 批量文件数量；
- 转换确认状态。

例如：

```text
3 Files
→ WEBP
```

这比只显示 `WEBP` 更有“正在操作文件”的感觉。

## 3.5 macOS 14 与新 Liquid Glass 的兼容策略

当前项目最低版本是 macOS 14。

建议不要为了追求新视觉直接把最低系统版本升级。

更好的方法：

### macOS 14 / 15

继续使用：

- `NSVisualEffectView`
- SwiftUI Material
- Vibrancy
- 系统颜色

### 支持新 Liquid Glass API 的系统

运行时增加 Progressive Enhancement：

- 新系统使用新 Glass API；
- 老系统继续走 NSVisualEffectView fallback。

这样既可以保住现有兼容范围，又能让新系统体验更接近 Apple 当前设计语言。

---

# 4. 多语言方案

## 4.1 产品范围

V2 建议首先支持：

1. **跟随系统**
2. **English**
3. **简体中文**

暂时不要一开始支持十几种语言。

先把语言架构做好，未来增加繁中、日文、韩文时只增加资源，不改业务代码。

## 4.2 哪些内容必须本地化

包括：

- Menu Bar；
- Drop Window；
- General / Formats / Compatibility / Folders / About；
- 工具名称；
- 状态提示；
- Error Alert；
- Dependency Diagnostics；
- 文件冲突、转换失败、权限错误；
- 新手引导；
- 通知。

不需要翻译：

- JPG / PNG / MP4 / DOCX 等格式缩写；
- FFmpeg / ImageMagick / Pandoc 等项目名；
- OrbitMorph 品牌名。

Slogan 可保留英文 `Drop. Spin. Convert.`，中文界面可以增加次级解释，例如：

> 拖入 · 旋转 · 转换

但不建议完全替换品牌英文 slogan。

## 4.3 技术建议

建议使用 Apple String Catalog：

```text
Localizable.xcstrings
```

而不是继续把英文直接写在 Swift 文件中。

建议统一：

```text
LocalizationManager
    ├── System
    ├── en
    └── zh-Hans
```

SwiftUI 文字使用 `String(localized:)` / localized keys。

AppKit 的：

- NSMenu；
- NSAlert；
- Status Item；

也应全部通过同一 localization layer 输出。

## 4.4 建议支持运行时切换

Settings → General 增加：

```text
Language
[ System Default ▼ ]
```

支持：

- System Default
- English
- 简体中文

理想体验是不重启 App 即切换。

如果第一阶段实现成本过高，也可以：

- 保存语言设置；
- 提示 “Restart OrbitMorph to apply language”。

但从长期架构看，建议让 SwiftUI 和 Menu Builder 都能够响应 `localeDidChange`。

---

# 5. 格式转换能力：目前缺什么

目前 OrbitMorph 已经有 36 种 FormatID 和 253 条本机验证路线。

这看起来很多，但按用户真正使用的“格式家族”来看，还有明显空白。

建议把格式能力从“扩展名单”改成下面这些 Category：

1. Image
2. Audio
3. Video
4. Document
5. Spreadsheet
6. Presentation
7. PDF
8. E-book
9. Vector / Design
10. Archive
11. Data / Developer
12. Font
13. 3D（后续）

这样产品更容易理解，技术也更容易维护。

---

# 6. 推荐整合的开源项目

以下建议不是“全部打包进去”，而是建议建立 Adapter / Plugin 层，按需检测用户本机工具。

## 6.1 LibreOffice — 优先级 P0

官网：
https://www.libreoffice.org/

命令行文档：
https://help.libreoffice.org/latest/zh-CN/text/shared/guide/start_parameters.html

### 最主要价值

补齐当前最大的格式缺口：

#### Spreadsheet

- XLS
- XLSX
- ODS
- CSV
- TSV

#### Presentation

- PPT
- PPTX
- ODP

#### Document

- DOC / DOCX / ODT / RTF
- PDF 输出

### 产品意义

如果 OrbitMorph 想成为“全面文件转换工具”，Office 文件是必须补的一层。

现在只有 Word 类文档，但没有 Excel 和 PowerPoint，这会让普通用户觉得功能仍不完整。

### 技术注意

LibreOffice headless 可以使用 `--convert-to`。

但不要每个文件都无脑冷启动一次 LibreOffice。

后续需要技术评估：

- 独立 UserInstallation；
- 并发锁；
- batch conversion；
- 持久 headless worker。

---

## 6.2 qpdf — 优先级 P0

文档：
https://qpdf.readthedocs.io/

### 推荐能力

PDF 不应该只是“PDF → JPG/PNG”。

建议增加：

- Split PDF；
- Merge PDF；
- Rotate pages；
- Extract pages；
- Encrypt；
- Decrypt；
- Linearize / Web Optimize；
- Remove metadata；
- Attachments；
- Repair / Rewrite。

### 产品意义

PDF 是高频独立工具类别。

这类功能比增加几十个冷门图片后缀更有用户价值。

---

## 6.3 OCRmyPDF + Tesseract — 优先级 P1

OCRmyPDF：
https://ocrmypdf.readthedocs.io/

Tesseract：
https://tesseract-ocr.github.io/

### 推荐能力

- 扫描 PDF → Searchable PDF；
- Image → OCR Text；
- Image → Searchable PDF；
- PDF OCR；
- 中文 + 英文 OCR；
- PDF/A。

Tesseract 本身可以输出 TXT、PDF、hOCR、TSV，并支持多语言模型。

### 产品意义

这是一个很强的差异化能力。

OrbitMorph 从“格式改后缀”升级为：

> **把不可搜索的扫描件变成可搜索的文件。**

这一类用户价值明显高于单纯路线数量。

---

## 6.4 Inkscape — 优先级 P1

官网：
https://inkscape.org/

CLI 文档：
https://wiki.inkscape.org/wiki/Using_the_Command_Line

### 推荐支持

- SVG
- PDF
- EPS
- PS
- PNG
- Plain SVG

### 产品意义

当前 OrbitMorph 对“设计文件 / 矢量文件”几乎没有覆盖。

SVG 是现在 Web / UI / Logo 工作非常高频的格式。

建议优先增加：

```text
SVG → PNG
SVG → PDF
SVG → EPS
PDF → SVG
EPS → SVG / PDF
```

---

## 6.5 Calibre `ebook-convert` — 优先级 P1

文档：
https://manual.calibre-ebook.com/generated/en/ebook-convert.html

Calibre 支持大量电子书输入和输出，包括：

- EPUB
- MOBI
- AZW / AZW3
- FB2
- DJVU
- CBZ
- CBR
- HTML
- DOCX
- ODT
- PDF 等。

### 产品意义

可以直接形成一个新的 E-book Category。

典型用户行为：

```text
EPUB → MOBI
EPUB → AZW3
MOBI → EPUB
DOCX → EPUB
EPUB → PDF
```

### 注意

Calibre 体积较大，因此更适合做“可选 Backend”，不建议第一阶段直接随 OrbitMorph DMG 打包。

---

## 6.6 OpenImageIO — 优先级 P1 / Pro Image

文档：
https://openimageio.readthedocs.io/

OpenImageIO 对专业图片格式覆盖很好，包括：

- OpenEXR
- JPEG 2000
- JPEG XL
- PSD
- RAW Camera
- HDR / RGBE
- DDS
- TGA
- SGI
- Cineon
- HEIC / AVIF
- TIFF / WebP 等。

### 产品意义

当前 ImageMagick 已经覆盖常见格式，不建议简单重复。

OpenImageIO 更适合用于：

> **专业影像 / CG / 摄影格式。**

建议增加 Pro Image 分类：

```text
EXR
HDR
PSD
JXL
JP2
RAW / DNG / NEF / ARW / CR2...
```

---

## 6.7 libvips — 优先级 P1（性能优化型）

文档：
https://libvips.github.io/

### 主要用途

libvips 不一定用来增加最多的新格式，而是用来解决：

- 超大图片；
- 批量缩图；
- WebP / AVIF / JXL；
- 高并发图片处理；
- 内存占用。

### 产品意义

未来如果 OrbitMorph 支持一次拖入几百张图片：

ImageMagick 的“单进程处理一个文件”模式可能不是最高效。

可以考虑：

> Common Image → libvips
>
> Long-tail / special formats → ImageMagick / OpenImageIO

不要三个后端互相抢同一路线，必须设计优先级规则。

---

## 6.8 MuPDF — 优先级 P2

文档：
https://mupdf.readthedocs.io/

`mutool` 可以处理：

- PDF
- XPS
- CBZ
- EPUB
- Markdown（部分工具）

并可输出：

- PNG
- PDF
- SVG
- HTML
- Text

### 推荐用途

用于：

- PDF / XPS 高质量渲染；
- PDF → SVG；
- PDF → Text / HTML；
- page extraction。

它可以和 qpdf 形成互补：

- qpdf：修改 PDF 结构；
- MuPDF：渲染和抽取 PDF 内容。

---

## 6.9 ExifTool — 优先级 P2

官网：
https://exiftool.org/

### 推荐能力

不把它定位为“格式转换”，而是 File Tools：

- 查看 Metadata；
- Clean Metadata；
- Copy Metadata；
- GPS Remove；
- Date Fix；
- EXIF / XMP / IPTC 迁移。

ExifTool 支持大量图片、音视频、RAW、Office 和其他文件元数据。

这会让 Tools Wheel 更有价值。

---

## 6.10 yq — 优先级 P2 / Developer

文档：
https://mikefarah.gitbook.io/yq

支持：

- YAML
- JSON
- XML
- INI / Properties
- CSV
- TSV

### 产品建议

增加一个 Developer / Data Category：

```text
JSON ↔ YAML
JSON ↔ XML
CSV ↔ JSON
TSV ↔ JSON
Properties ↔ YAML
```

它是一个单独的 Go binary，部署相对简单。

这类能力对开发者用户非常有吸引力。

---

## 6.11 FontForge — 优先级 P3

文档：
https://fontforge.org/docs/scripting/scripting.html

适合：

- TTF
- OTF
- PostScript Fonts
- SVG Fonts
- 部分 bitmap font

可以增加 Font Category。

但这是专业用户需求，不建议排在 Office / PDF / SVG / OCR 前面。

---

## 6.12 Assimp — 优先级 P3

GitHub：
https://github.com/assimp/assimp

支持大量 3D Import / Export：

- OBJ
- STL
- PLY
- 3MF
- GLTF / GLB
- DAE
- FBX（注意不同格式支持成熟度不同）
- X3D 等。

### 产品建议

如果未来 OrbitMorph 要进入 Creator / 3D 用户市场，可以增加：

```text
3D Models
```

但现在不建议把这部分放进 V2 核心范围。

---

# 7. 推荐的格式扩展优先级

## P0 — V2 必做

### UX

- 更强的 Glass UI；
- 中英文；
- 快捷键与转盘反馈继续打磨。

### Formats

- XLS / XLSX / ODS / CSV；
- PPT / PPTX / ODP；
- PDF split / merge / optimize / encrypt；
- SVG。

推荐 Backend：

- LibreOffice
- qpdf
- Inkscape

## P1 — 高价值扩展

- OCR；
- EPUB / MOBI / AZW3；
- EXR / PSD / JXL / RAW；
- PDF → SVG / Text；
- 批量高性能图片处理。

推荐 Backend：

- OCRmyPDF + Tesseract
- Calibre
- OpenImageIO
- libvips
- MuPDF

## P2 — 工具型能力

- EXIF Metadata；
- JSON / YAML / XML / CSV / TSV；
- 更多 Archive 格式。

推荐：

- ExifTool
- yq
- libarchive / unar

## P3 — 专业生态

- Font；
- 3D；
- CAD / GIS 等。

推荐：

- FontForge
- Assimp
- 后续再评估 Blender / GDAL 等重型工具。

---

# 8. 不建议“直接把所有开源项目塞进 DMG”

这是后续架构最重要的一点。

如果把：

```text
FFmpeg
ImageMagick
LibreOffice
Calibre
Inkscape
OCRmyPDF
Tesseract
OpenImageIO
...
```

全部塞进 App：

最终安装包很容易从目前几 MB 变成数 GB。

而且会出现：

- License 管理复杂；
- 更新困难；
- CVE / 安全维护困难；
- Apple Notarization 更麻烦；
- 首次下载体验差；
- 多个 Backend 冲突。

## 推荐产品方案：Backend Packs

### Core Pack

默认 App 自带 / 使用系统能力：

- ImageIO
- PDFKit
- textutil
- ditto / tar

### Media Pack

检测：

- FFmpeg
- ImageMagick / libvips

### Office Pack

检测：

- LibreOffice

### PDF & OCR Pack

检测：

- qpdf
- OCRmyPDF
- Tesseract
- MuPDF

### Creator Pack

检测：

- Inkscape
- OpenImageIO
- Calibre

### Advanced Pack

- FontForge
- Assimp
- yq

Settings → About 或新建 `Extensions` 页面显示：

```text
Media Pack      ✓ Ready
Office Pack     ○ Install LibreOffice
PDF & OCR Pack  ○ Install OCR tools
Creator Pack    ✓ Partially available
```

这比给用户展示十几个独立 Unix 命令更产品化。

---

# 9. 当前代码架构建议

当前项目可以继续演进，但如果直接继续往 `ConversionRegistry` 中增加几百条 if / switch，后续维护会迅速失控。

建议先做一次“可扩展后端架构整理”，再扩格式。

## 9.1 ConversionRegistry 从硬编码改成 Capability Registry

当前逻辑主要由：

```text
ConversionRegistry
ToolRegistry
DependencyResolver
```

直接决定路线。

建议变成：

```text
BackendRegistry
   ├── NativeImageBackend
   ├── FFmpegBackend
   ├── ImageMagickBackend
   ├── LibreOfficeBackend
   ├── QPDFBackend
   ├── CalibreBackend
   ├── InkscapeBackend
   └── ...
```

每个 Backend 自己声明：

```text
id
version
installed
inputFormats
outputFormats
capabilities
qualityScore
speedScore
supportsBatch
supportsProgress
supportsCancel
```

然后 OrbitMorph 自动形成兼容矩阵。

不要继续手工维护所有 source → target 组合。

## 9.2 引入 Backend Protocol

建议类似：

```text
ConversionBackendAdapter
    canHandle(source, target)
    makeJob(...)
    convert(...)
    validateOutput(...)
```

这样增加 LibreOffice 时，不需要修改核心 ConversionEngine 大量 switch。

## 9.3 同一路线允许多个 Backend，但必须有路由优先级

例如：

```text
PNG → WEBP
```

可能同时支持：

- ImageIO
- ImageMagick
- libvips
- OpenImageIO

不能随机选择。

建议建立 Routing Policy：

```text
1. Native first
2. User-selected backend
3. Quality preference
4. Speed preference
5. Fallback backend
```

甚至未来在 Settings 增加：

```text
Conversion preference
○ Balanced
○ Best Quality
○ Fastest
○ Smallest File
```

这会成为很好的产品能力。

---

# 10. 性能优化建议

## 10.1 不要无限并发启动外部进程

当用户一次拖入 100 个文件时，如果直接启动 100 个 FFmpeg / LibreOffice 进程，会拖垮 Mac。

建议增加：

```text
JobQueue
```

并按 Backend 控制 concurrency：

- LibreOffice：1；
- FFmpeg：根据 CPU / GPU 控制；
- Image：2–4；
- lightweight native jobs：更高。

## 10.2 Dependency 检测和 Capability Probe 缓存

不要每次打开转盘都重新：

```text
which ffmpeg
ffmpeg -encoders
pandoc --list-output-formats
```

建议 App 启动后：

```text
BackendDiscoveryService
```

一次检测：

- tool path；
- version；
- supported codec；
- supported format。

缓存结果。

只有：

- 用户点击 Refresh；
- Homebrew 环境发生改变；
- App 重启；

才刷新。

## 10.3 Batch 优先

如果一个 Backend 本身支持批处理，应一次处理多个文件，而不是逐文件启动进程。

最明显的是：

- LibreOffice；
- Image tools；
- 某些 archive 工具。

## 10.4 后台任务需要 Progress / Cancel

当前 V1 更偏“执行完给结果”。

随着 LibreOffice / OCR / 大视频加入，必须增加：

```text
Job
├── queued
├── running
├── progress
├── cancelling
├── completed
└── failed
```

转盘选择结束以后可以出现一个极简浮动进度条，而不是弹大型窗口。

## 10.5 保留当前 Atomic Output 设计

当前已经有：

- temporary output；
- collision-safe naming；
- batch failure rollback。

这部分设计很好，不建议推翻。

所有新 Backend 必须遵守同一个 output transaction contract。

---

# 11. 代码结构建议

## 当前值得拆分的位置

### `SettingsView.swift`

目前五个设置页面集中在一个较大的 Swift 文件里。

建议未来拆成：

```text
Settings/
  GeneralSettingsView.swift
  FormatSettingsView.swift
  CompatibilitySettingsView.swift
  FolderSettingsView.swift
  AboutSettingsView.swift
  LanguageSettingsView.swift
```

共享：

```text
GlassCard
SettingsSectionHeader
SettingRow
```

这也会让玻璃风格统一，而不是每页单独写背景。

### `AppState`

当前 AppState 同时承担：

- Settings；
- dependency；
- output folder；
- status；
- job state。

随着 V2 扩展，建议拆成：

```text
AppState
  LocalizationManager
  SettingsManager
  BackendManager
  JobManager
  OutputLocationManager
```

否则以后语言切换、插件刷新、任务队列会全部堆进同一个对象。

---

# 12. Error / Diagnostics 建议

现在 About 直接展示命令路径，这对开发者很好，但对普通用户还不够产品化。

建议分成：

## 普通模式

```text
Office Conversion
Not Available
Install LibreOffice
```

## Advanced Diagnostics

展开后才显示：

```text
/opt/homebrew/bin/ffmpeg
Version 8.x
libx264 ✓
libvorbis ✓
```

错误也不要直接把 command stderr 当主文案。

建议：

```text
Conversion failed
This video does not contain an audio track.
```

下面提供：

```text
Show Technical Details
```

再显示 FFmpeg 原始输出。

---

# 13. 测试体系建议

当前 253 路真实转换测试是非常好的基础。

未来建议继续保持这个优势。

## 每新增 Backend 必须包含

1. Dependency detection test
2. Capability test
3. Route generation test
4. Real output test
5. Invalid file test
6. Unicode filename test
7. Existing destination test
8. Cancel test（支持时）

## UI 新增测试

建议增加截图 / Snapshot Matrix：

```text
English + Light
English + Dark
Chinese + Light
Chinese + Dark
Reduce Transparency
Increase Contrast
Reduce Motion
```

尤其玻璃 UI 不适合只看代码判断，需要视觉回归。

---

# 14. 建议产品路线图

## V2.0 — 先把“Mac 产品感”补齐

重点：

- Glass UI；
- 中英文；
- Settings 视觉统一；
- Wheel 玻璃和动画细节；
- Backend Registry 重构；
- JobQueue / Progress 基础。

**暂时不要一次增加几十个新格式。**

## V2.1 — Office + PDF

加入：

- LibreOffice；
- XLS/XLSX/ODS；
- PPT/PPTX/ODP；
- qpdf；
- PDF Tool Wheel。

这是普通用户价值最高的一批。

## V2.2 — Creator

加入：

- SVG / EPS；
- Inkscape；
- OpenImageIO；
- JXL / EXR / PSD / RAW；
- ExifTool。

## V2.3 — OCR + E-book

加入：

- OCRmyPDF；
- Tesseract；
- Calibre；
- EPUB/MOBI/AZW3。

## V3 — Extension Ecosystem

如果产品验证成立，再考虑：

- FontForge；
- Assimp；
- Developer/Data Pack；
- 外部 Backend Plugin SDK。

---

# 15. 产品经理最终建议

我不建议 OrbitMorph 下一步把目标设定成：

> “支持 100 种文件，1000 条转换路线。”

这会让技术复杂度迅速增加，但产品体验未必更好。

更好的目标是：

> **用户拖一个常见文件进来，几乎总能看到有价值的下一步。**

例如：

### 拖入 PDF

看到：

```text
PNG
JPG
DOCX
OCR
Split
Merge
Compress
Encrypt
```

### 拖入 XLSX

看到：

```text
CSV
ODS
PDF
HTML
XLS
```

### 拖入 SVG

看到：

```text
PNG
PDF
EPS
JPG
```

### 拖入 EPUB

看到：

```text
MOBI
AZW3
PDF
DOCX
```

这才是真正的“Universal Converter”。

技术团队后续可以围绕三个核心 KPI 来做：

1. **高频文件覆盖率**，而不是单纯格式数量；
2. **拖入到可执行动作出现的时间**；
3. **真实转换成功率与输出质量**。

---

# 16. 建议技术团队下一步先做的 8 件事

按顺序建议：

1. 抽出统一 Glass Design Tokens / GlassCard。
2. 完成 String Catalog，消除 UI 硬编码英文。
3. General 增加 System / English / 简体中文。
4. 将 ConversionRegistry 改为 Backend Capability Registry。
5. 引入 Backend Adapter Protocol 和 route priority。
6. 增加 JobQueue / concurrency control / cancel 基础。
7. 第一批接 LibreOffice + qpdf + Inkscape。
8. 跑新的真实转换矩阵和中英文 UI snapshot 后，再扩 OCR / Calibre / OpenImageIO。

如果这 8 项完成，OrbitMorph 会从目前的“功能完整 V1”，明显升级成一个可长期扩展的产品架构。

---

# 17. 外部资料

- Apple Human Interface Guidelines — Materials\
  https://developer.apple.com/design/human-interface-guidelines/materials
- Apple NSVisualEffectView\
  https://developer.apple.com/documentation/appkit/nsvisualeffectview
- LibreOffice command-line conversion\
  https://help.libreoffice.org/latest/zh-CN/text/shared/guide/start_parameters.html
- qpdf\
  https://qpdf.readthedocs.io/
- OCRmyPDF\
  https://ocrmypdf.readthedocs.io/
- Tesseract OCR\
  https://tesseract-ocr.github.io/
- Inkscape CLI\
  https://wiki.inkscape.org/wiki/Using_the_Command_Line
- Calibre ebook-convert\
  https://manual.calibre-ebook.com/generated/en/ebook-convert.html
- OpenImageIO\
  https://openimageio.readthedocs.io/
- libvips\
  https://libvips.github.io/
- MuPDF\
  https://mupdf.readthedocs.io/
- ExifTool\
  https://exiftool.org/
- yq\
  https://mikefarah.gitbook.io/yq
- FontForge\
  https://fontforge.org/
- Assimp\
  https://github.com/assimp/assimp

---

**文档版本：V1.0**\
**日期：2026-10-03**\
**用途：OrbitMorph V2 产品 / 技术评审输入**

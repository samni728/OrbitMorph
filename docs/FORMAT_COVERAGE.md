# 格式覆盖、缺口与路线图

## 这次核查的结论

原项目 V1 登记 36 种格式，已有 V2 规范列出的 SVG、WMV、WMA、SRT、VTT 尚未接入。按本轮确认范围补齐这五种后，识别格式为 41 种，新增 Subtitle 分类。

“识别格式”“可读取输入”“可写输出”“两者之间有可用路线”是四个不同事实。界面应只开放已实现、满足本机依赖/编码器条件的路线，不能只在枚举里加名字就宣称支持。

## 本轮完成范围

| 新格式 | 输入与输出 | 实现与保真边界 |
| --- | --- | --- |
| SVG | 输入 → PNG/JPG/WEBP/PDF | ImageMagick 实际读取能力门控；目前不提供 SVG 输出或可编辑矢量化 |
| WMV | 视频输入、具备编码器时的视频输出 | FFmpeg，真实编码能力检测；可从含音轨输入抽音频 |
| WMA | 音频输入、具备编码器时的音频输出 | FFmpeg，按本机构建的编码器开放 |
| SRT | 输入/输出，与 VTT 双向 | 原生字幕 adapter，不混入文档路线 |
| VTT | 输入/输出，与 SRT 双向 | 原生字幕 adapter；各自独有的样式/位置/元信息不能保证保留 |

上述格式必须纳入真实矩阵。最终可用路线和验收结果见 [转换路线验收](verification/转换路线验收.md)，不会用规划替代测试。

字幕范围是 UTF-8 基础 cue。VTT NOTE 注释可忽略，STYLE/REGION 与 cue 布局 settings 当前拒绝；异常时间轴、缺 cue 边界和不安全正文会报错。命名 VTT cue ID 转 SRT 时改成连续数字序号，不声称跨格式保留所有元信息。

## 当前识别格式

| 类别 | 格式 |
| --- | --- |
| Image（9） | JPG/PNG/WEBP/HEIC/TIFF/AVIF/BMP/GIF/SVG |
| Document（8） | PDF/DOC/DOCX/TXT/MD/RTF/HTML/ODT |
| Audio（9） | MP3/M4A/AAC/WAV/FLAC/OGG/OPUS/AIFF/WMA |
| Video（7） | MP4/MOV/MKV/WEBM/AVI/M4V/WMV |
| Archive（6） | ZIP/7Z/TAR/TGZ/GZ/RAR |
| Subtitle（2） | SRT/VTT |

扩展名别名如 JPEG、TIF、HEIF、Markdown、OGA、AIF、TAR.GZ 会归一化，不重复计算为新格式。

## 常用缺口：哪些还没有做？

| 范围 | 典型格式/动作 | 现有工具能否解决 | 建议 |
| --- | --- | --- | --- |
| Office 表格与演示 | XLS/XLSX/ODS、PPT/PPTX/ODP | Pandoc 部分输入/输出不等于完整公式、图表、母版、版式互转；高保真需 Office 专用后端 | Next：评估 LibreOffice，先锁定几条高频路线 |
| 电子书 | EPUB/MOBI/AZW3 | Pandoc 可覆盖部分 EPUB/结构文档；跨电子书家族通常需 Calibre | Next 独立迭代，定义目录/元数据/布局要求 |
| PDF 与扫描文件 | DOCX、拆分、优化、加密、OCR | 已有 PDFKit 合并/转图；其他操作需针对性实现或 qpdf/OCR 工具 | Next 按动作而非后缀拆分 |
| 摄影/专业图片 | RAW/CR2/NEF/ARW/DNG、EXR/JXL/JP2/ICO/PSD | ImageMagick 构建可能提供部分能力，需实际读取/写出及色彩、多帧验证 | 小批量补齐，不能直接开放整个 format list |
| 专业矢量 | EPS/AI/PDF → SVG、SVG → EPS | ImageMagick 偏栅格处理，不代表矢量保真；需要 Inkscape/专用后端 | Later 或 Creator 范围 |
| 更多媒体容器 | FLV/TS/MTS/M2TS/3GP、CAF 等 | FFmpeg 可能可做，需要明确编码器、容器与真实路线 | 按实际文件使用频率补齐 |
| 数据/邮件/日历 | JSON/YAML/XML/CSV/TSV、EML/ICS | 需要定义字段、结构、编码和转换语义；ExifTool 不是内容转换器 | Later |

本机可用 FFmpeg、ImageMagick、Pandoc、Ghostscript、7zz、ExifTool；未找到用户常规安装的 LibreOffice、Calibre、qpdf 或 Inkscape。开发环境的 bundled runtime 不应误当用户产品依赖。

## 迭代边界

- **Now**：本轮五个格式、真实产物测试、设置接线、README 与截图、仓库推送。
- **Next**：首次引导/本地化、进度/取消、内容级媒体目标过滤；Office/PDF 或其他高频格式各自定义一条闭环。
- **Later**：专业图像/矢量、电子书、更多媒体、数据文件，逐批验证后扩展。
- **Risk**：工具体积、许可、色彩/多帧/排版保真、依赖安装、公证和跨机器分发。

已有 V2 产品评审和设计文档是后续输入，不意味着所有清单均已开发。新增 backend 必须有能力门控和逐路线真实测试。

# OrbitMorph 1.2.1 格式覆盖与边界

当前识别58种格式。注册路线依赖本机转换器、编解码能力和用户禁用设置；格式名不等于任意两种格式均可互转。版本1.1.0的41格式/294路线为历史记录。

真实轮盘按当前输入查询可用目标，多文件取交集；截图demo同样使用PNG的实际目标，不能把视频或电子书目标混入图片展示。超过八个项目通过中心纵向数字页码选择：拖到页码停留350ms切换外圈，再到目标松手；在中心松手不转换。

| 类别 | 数量 | 格式 |
| --- | ---: | --- |
| 图片 | 13 | JPG/PNG/WEBP/HEIC/TIFF/AVIF/BMP/GIF/SVG/ICO/JP2/JXL/PSD |
| 文档 | 8 | PDF/DOC/DOCX/TXT/MD/RTF/HTML/ODT |
| 表格 | 3 | XLS/XLSX/ODS |
| 演示 | 3 | PPT/PPTX/ODP |
| 电子书 | 3 | EPUB/MOBI/AZW3 |
| 音频 | 10 | MP3/M4A/AAC/WAV/FLAC/OGG/OPUS/AIFF/WMA/CAF |
| 视频 | 10 | MP4/MOV/MKV/WEBM/AVI/M4V/WMV/FLV/TS/3GP |
| 归档 | 6 | ZIP/7Z/TAR/TGZ/GZ/RAR |
| 字幕 | 2 | SRT/VTT |

JPEG/TIF/HEIF/OGA/AIF等扩展名别名不重复计数。MTS/M2TS归TS输入，输出普通MPEG-TS；JP2/J2K等统一识别不承诺多图层或特殊容器语义。

## 本轮新增闭环

| 范围 | 路线与后端 | 保真/验收边界 |
| --- | --- | --- |
| Office表格 | XLS/XLSX/ODS互转及PDF，LibreOffice | fixture回读两工作表顺序、中文、7/5/12数值及加法公式；这不等于所有公式、宏、图表、外链兼容 |
| Office演示 | PPT/PPTX/ODP互转及PDF，LibreOffice | fixture回读两页顺序和中文；母版、动画、字体、复杂版式未全面验收 |
| 结构文档PDF | DOC/DOCX/ODT/RTF/HTML/TXT→PDF，LibreOffice | 不承诺原软件逐像素排版或宏执行 |
| 电子书 | EPUB/MOBI/AZW3互转；TXT/HTML/DOCX输入；TXT/DOCX/PDF输出，Calibre | 双章节含目录、图、元数据夹具；断言正文可回读及中文PDF，不宣称目录/封面/图像/元数据全面保真；不解除DRM |
| PDF与图片文字 | TXT/DOCX，PDFKit/Vision/textutil | PDF逐页OCR并合并文本层，考虑混合/旋转页；输出纯文字，不重建排版、表格、图片或复杂栏顺序 |
| 常用媒体 | FLV/TS/3GP/CAF，FFmpeg/ffprobe | 指定容器/编码器并探测，再用ffprobe验证真实流；输入无音轨时无法抽音频；TS/3GP/FLV质量参数按编码器生效 |
| 常用图片 | ICO/JP2/JXL读写，PSD输入，ImageMagick | 小fixture真实写入/读回后开放；PSD采用合成图，不提供图层编辑保真 |

应用在界面创建前完成能力探测。新增编码器或图片coder缺失时隐藏相关目标；不将ImageMagick整张format list当作支持清单。WMV/WMA/FLV/TS/3GP/CAF输出同时要求ffprobe（Homebrew FFmpeg自带），缺失时不开放这六类目标。

文字提取输入为PDF及JPG/PNG/TIFF/BMP/HEIC/WEBP/AVIF；其他图片格式当前不开放OCR目标。

## 已有边界

SVG只输入栅格化，无SVG/EPS/AI矢量输出。PDF转图逐页输出，静态目标/原生ImageIO后备通常取首帧。归档可输出ZIP/7Z/TAR/TGZ，GZ/RAR仅输入，拒绝路径穿越及链接成员。

字幕仅UTF-8基础cue，保留正文/时间；VTT NOTE忽略，STYLE/REGION及cue布局settings拒绝。跨格式独有样式/位置不承诺保留。

外部工具不随app/DMG分发。Office、Calibre、OCR新backend需要独立真实产物验收；跨机器路线数量不同。

**1.2.1 最终本机矩阵：注册 554、测试 554、通过 554、失败 0、未覆盖 0。** 共识别 58 种格式；每条路线使用真实生成/官方夹具，并解析产物。具体工具组合与路线见[转换路线验收](verification/转换路线验收.md)和[矩阵 JSON](verification/conversion-matrix.json)。

## 下一轮

| 阶段 | 范围 |
| --- | --- |
| Now | 58格式实际路线、文字提取、教程/中英文、声音、最终截图与可复现app/DMG |
| Next | 百分比进度/取消、内容级媒体过滤、PDF拆分/优化/其他动作、电子书元数据/目录/图片专门保真样例 |
| Later | 摄影RAW、EXR、专业矢量、复杂多帧编辑、数据/邮件/日历转换 |
| Risk | 工具体积/许可、跨套件公式与宏、色彩/字体/排版、签名公证及跨机器分发 |

专业RAW（CR2/NEF/ARW/DNG等）、EXR、矢量编辑/输出仍不支持；工具delegates出现相关名字不构成可用产品路线。

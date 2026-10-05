# 常用格式补齐与发布计划

目标：在已有本地转换闭环内补齐 Office、电子书、文字提取和常用媒体/图片；真实产物验收通过后更新 README、截图、DMG 并推送。

架构：继续使用 FormatID → ConversionRegistry → ConversionEngine → adapter。输入与输出均本地；复用临时输出、排他提交和批次回滚。不增加 API、账号或云端服务。

## 边界与文件责任

- Office：LibreOfficeAdapter.swift、OfficeConversionTests.swift；XLS/XLSX/ODS 和 PPT/PPTX/ODP 组内互转及 PDF，现有文字文档导出 PDF。
- 电子书：CalibreAdapter.swift、EbookConversionTests.swift；EPUB/MOBI/AZW3 互转、文字文档生成电子书、电子书导出文本/DOCX/PDF；拒绝加密/DRM 文件，布局会重排。
- 文字提取：NativeTextAdapter.swift、TextExtractionTests.swift；可搜索 PDF 先读文本层，扫描页和常用图片使用 Vision OCR，输出 TXT 或纯文本 DOCX。无文字时报错，不伪装成功。
- 常用扩展：Formats.swift、DependencyResolver.swift、registry、engine、工具门控和 CommonFormatGapTests；FLV/TS/3GP/CAF、ICO/JP2/JXL 双向，PSD 合成图输入专用。MTS/M2TS 归 TS 输入，输出为标准 TS。
- 集成验收：ConversionMatrixTests.swift 复用 Office/Ebook/Text fixture helper；逐个注册路线解析真实输出，禁止未覆盖路线。
- 文档与分发：README、USER_GUIDE、DEVELOPMENT、FORMAT_COVERAGE、Credits、验收记录、截图和 DMG。

## 测试与完成顺序

- [ ] 先写并观察缺失行为失败：格式分类、门控、OCR、adapter 输出与内容。
- [ ] 独立实现 adapters，验证隔离配置、Unicode 路径、损坏输入、非空/结构验证、重名与批次回滚。
- [ ] 核对 Office 公式/数值/工作表、幻灯片顺序和 PDF；电子书章节/中文/目录/图像；媒体容器/编码器/时长；图片尺寸/可读性；OCR 文本与页顺序。
- [ ] 整体跑 swift test 和 ORBITMORPH_FULL_MATRIX=1 swift test，所有注册路线零失败、零遗漏。
- [ ] 独立审查、release 构建、六张真实界面截图、DMG 验证。
- [ ] README 与机器报告使用实际数量；保真和依赖限制公开；提交并正常推送 main，核对远端 hash。

专业 RAW、EXR、可编辑矢量、结构化数据和邮件的转换语义尚未验收，不以简单增加扩展名冒充支持。实体 Finder 修饰键拖甩的人工验收仍单独记录。

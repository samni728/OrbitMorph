# OrbitMorph 1.2.1 使用说明

## 安装与首次使用

需要 Apple Silicon、macOS 14+。从源码执行 `scripts/build-app.sh`、`scripts/package-dmg.sh` 后打开 DMG，将 app 拖入 Applications。开发可用 `swift run OrbitMorph`。

首次教学提供 PNG/MP4 内置样本：转盘显示在教学窗口内，可按快捷键拖动示例或点击“观看演示”。这里只模拟可选目标，不转换、保存文件或接收用户文件。窗口可拖动，红色关闭按钮和“跳过”都可关闭；展示后即记为已看过，重启或升级不重复显示，菜单也没有重新打开入口。语言可跟随系统，也可在 General 选择 English/简体中文。教程样本与反馈声音在 app 内，FFmpeg、LibreOffice、Calibre 等工具单独安装。

```sh
brew install ffmpeg imagemagick pandoc sevenzip ghostscript
brew install --cask libreoffice calibre
```

新装转换器后重启应用，在 About 查看检测结果。ffprobe随Homebrew FFmpeg安装，WMV/WMA/FLV/TS/3GP/CAF增强输出需要它校验实际流；缺失时隐藏这些目标。缺工具不影响其他系统原生路线。教学样本只用于界面演示，原始 app 包不会被改写。

## 日常 Finder 快捷键拖放

按住 Shift 并开始拖动 Finder 文件后，转盘在鼠标所在屏幕唤出；单独按修饰键不显示转盘。一个、两个或三个屏幕都以当前鼠标所在屏幕定位，不固定在主屏。转盘出现后滑向外圈目标分区并松开鼠标，橙色高亮与中心提示显示当前动作。

超过八个项目时，中心纵向显示数字页码：两页上1下2，三页从上到下1/2/3。保持文件拖拽，移动到所需页码并停留350ms；外圈切换后，再移动到目标分区并松开执行转换。页码用于切换，不是输出目标；在中心松手不会转换。释放修饰键、移出转盘后松开或按 Escape 可取消拖拽。

多文件只显示共同目标，未知格式不会被当作有效输入。Option + Shift 打开工具转盘，超过八个工具项目时也遵循上述翻页方式。

没有 Drop Window 或手动投放转换入口。菜单栏只提供设置、关于、最近输出和退出；Reveal Last Outputs 在 Finder 中选中最近产物。当前任务提供忙碌/成功/失败反馈，百分比与执行中取消仍在后续范围。

应用只保留一个运行实例。再次打开会激活已有实例，新进程退出；升级前先退出已经运行的旧版本，避免不同版本同时响应拖拽。

## 设置

| 页面 | 作用 |
| --- | --- |
| General | 语言、Glass/Solid、登录启动、声音/触觉、拖拽修饰键；遵循 Reduce Motion |
| Formats | 真实可用输出和适用参数：图片质量、音频码率、H.264 预设、归档压缩级别、元数据 |
| Compatibility | ✓ 启用、○ 用户禁用、— 不可用；修改会影响实际目标 |
| Folders | 保存源文件旁或默认/分类目录，使用 bookmark 持久化 |
| About | 版本、平台和本机转换器路径 |

参数只作用于支持它们的 backend；Office/电子书并不提供任意质量、码率或全局元数据清除承诺。新工具安装后需重启检测。不能在矩阵中强行开启未实现的路线。

## 文件与目录

默认保存到源文件旁；配置分类目录时按输入类型匹配，缺分类则使用默认目录，再没有则用源目录。视频抽音频用 Video，电子书输出 DOCX 用 Ebook。

重名追加 `-converted`、`-converted-2`；PDF 转图逐页生成 `name-page-1.png` 等。批次失败清理本批次先前产物，保留原文件及已有输出。归档拒绝路径穿越和链接成员，解压到新的独立目录。

## 转换与边界

| 场景 | 能力与限制 |
| --- | --- |
| 常用图片 | 常规栅格互转；ICO/JP2/JXL 按真实读写能力开放；静态目标一般取首帧 |
| SVG/PSD | 输入转换；SVG 栅格化，PSD 使用合成图，不输出可编辑矢量或保留图层 |
| PDF/扫描图片 | TXT/DOCX 文字提取；PDF逐页OCR并合并可用文本层，处理扫描正文和页码/水印混合页及旋转页。DOCX 是可编辑文字，不是原版式复原 |
| Office 表格 | XLS/XLSX/ODS 互转和 PDF；基础数值/公式已有回读测试，复杂公式、宏、外链与图表不保证兼容 |
| Office 演示 | PPT/PPTX/ODP 互转和 PDF；字体、母版、动画和复杂布局可能改变 |
| 电子书 | EPUB/MOBI/AZW3 互转；TXT/HTML/DOCX 输入，TXT/DOCX/PDF 输出。目录、图片、封面与元数据尚未全面保真验收，不能解除 DRM |
| 媒体 | FFmpeg 转码、GIF、抽音频；输入无音轨时抽音频报错。MTS/M2TS 归 TS，输出普通 MPEG-TS |
| 字幕 | SRT/VTT 的 UTF-8 基础 cue、中文、多行和时间轴；不保证格式独有样式和布局 |

WMA/WMV/CAF/FLV/TS/3GP 等目标依本机编码器/封装能力显示。EXR、摄影 RAW、专业矢量转换与完整多帧编辑尚未支持。

字幕支持 BOM、Windows 换行、多行正文和 VTT cue ID；转 SRT 使用连续数字序号。NOTE 注释忽略，STYLE/REGION/cue 位置 settings 拒绝；畸形时间轴或不安全正文明确报错。

## 工具转盘

常规栅格图提供 Resize（最长边限定 1920）、Rotate（90°）、Clean、Compress、Archive；SVG/PSD 只提供 Archive。视频提供 Compress、Clean、Audio（MP3）、GIF、Archive；音频提供 Compress、Clean、Archive。多个 PDF 可按输入顺序 Merge。Office/电子书/字幕可 Archive，归档可 Extract，动作还取决于工具能力。

工具快捷操作和 Formats 默认参数是不同入口。无损 PCM 格式的 Compress 不保证体积下降。

## 常见问题

**目标没出现**：检查 About、Compatibility 禁用项、多文件共同目标，以及输入内容/工具能力。

**OCR 缺文字或顺序异常**：使用清晰、正向的印刷文字；复杂栏排、手写、低分辨率和扫描质量影响结果。提取结果需核对。

**Office/电子书版式改变**：跨格式布局并不等同原软件编辑能力；先对副本验证关键页、公式和图像。

**另一台 Mac 路线变少**：工具未随 DMG 分发；按需要安装。当前 app 是 ad-hoc 签名，尚未做 Developer ID 公证。

**快捷键没效果**：确认正在拖动真实文件并持续按住设定修饰键；在 About 检查依赖，在 Compatibility 检查该输入的目标是否启用。

**看不到下一页格式**：文件拖拽中移到中心页码并停留350ms，外圈切换后再移到目标松手；不要在中心松手。

**转盘出现在其他屏幕或出现两次**：当前版本按鼠标所在屏幕定位并限制单实例；先退出仍在运行的旧版本，再重新打开当前 app。

# OrbitMorph 使用说明

## 安装和启动

需要 Apple Silicon、macOS 14+。从源码执行 `scripts/build-app.sh`、`scripts/package-dmg.sh` 后打开 `dist/OrbitMorph.dmg`，将应用拖入 Applications。开发可用 `swift run OrbitMorph`。

默认显示 Drop Window，并在菜单栏保留入口。关闭窗口后通过 Open Drop Window 重新打开。当前尚无首次引导或中英文切换。

## 快捷键与普通拖放

在 Finder 开始拖动文件，持续按住 Shift。转盘出现后，移动到目标分区；橙色高亮和中心文字显示动作，松开鼠标执行。中心是空操作区。释放修饰键、移出转盘后松开或按 Escape 可取消。

超过八个目标可滚轮翻页，或点击 More。多文件只显示共同目标；未知扩展名不会被当成有效输入。Option + Shift 打开工具转盘。快捷键是拖动期间的修饰键，单独按键不会无条件弹出菜单。

普通入口：把文件拖入 Drop Window，再点击格式；或在菜单栏选择 Convert Files…。Reveal Last Outputs 在 Finder 中选中最近一次产物。

## 五个设置页面

| 页面 | 配置与作用 |
| --- | --- |
| General | Glass/Solid、登录启动、声音/触觉、两套修饰键；动画遵循 Reduce Motion |
| Formats | 仅列真实可用输出；质量、音频码率、适用的 H.264 预设、ZIP/7Z 压缩级别、元数据 |
| Compatibility | ✓ 启用、○ 用户禁用、— 不可用；矩阵横向可滚动，修改会影响实际目标 |
| Folders | 源文件旁、默认目录、按输入类别的目录，通过 bookmark 持久化 |
| About | 版本、平台与本机转换器路径状态 |

新安装工具后重启应用更新检测。不能在矩阵中强行开启未实现的路线。JPG 默认质量 92%，WEBP 88%，HEIC/AVIF 85%；Reset this format 清除用户覆盖。

## 文件与目录规则

默认保存到源文件旁。选择输出目录后可以按类别保存，缺类别目录则使用默认目录，再没有则使用源目录。分类看输入：WMV → MP3 使用 Video，SRT → VTT 使用 Subtitle。

重名使用 `name-converted.ext`、`name-converted-2.ext`。PDF 转图逐页生成，如 `name-page-1.png`。批次失败会清理本批次先前生成的文件；原文件和既有产物不会被静默覆盖。

## 工具转盘

| 输入 | 当前操作 |
| --- | --- |
| 常规图片 | Resize（限定 1920×1920，不放大小图）、Rotate（90°）、Clean（移除元数据）、Compress（质量 75）、Archive |
| SVG | Archive；当前没有原格式 SVG 编辑/矢量化工具 |
| 视频 | Compress、Clean、Audio（MP3）、GIF、Archive，媒体处理需 FFmpeg |
| 音频 | Compress、Clean、Archive，媒体处理需 FFmpeg |
| 多个 PDF | Merge（按输入顺序）、Archive |
| 其他文档/字幕 | Archive |
| 归档 | Extract，按本机可用解码工具显示，输出到新的独立目录 |

工具快捷操作与 Formats 默认参数是不同入口。归档转换拒绝路径穿越与链接成员，不提供创建 RAR/GZ。

## 新增格式

SVG 只读入转 PNG/JPG/WEBP/PDF，可能经过栅格化，不输出可编辑 SVG。WMV/WMA 取决于本机编码器，缺失时隐藏相应目标。SRT ↔ VTT 是原生转换，不需要 FFmpeg，支持常见字幕文本和时间轴；各自独有样式、位置或语义不能保证保留。

当前字幕 adapter 面向 UTF-8 的基础 cue：支持 BOM、Windows 换行、多行正文、数字或命名 VTT cue ID；转 SRT 会生成连续数字序号。VTT 的 NOTE 注释忽略，STYLE/REGION 块和 cue 位置/布局 settings 会明确拒绝。畸形时间轴或正文中不能安全表达的 `-->` 也会报错，不生成伪成功文件。

## 常见问题

**格式不出现**：检查 About 的工具状态、Compatibility 禁用项、多文件目标交集。新装工具后重启。

**快捷键没效果**：确认正在真正拖文件，并持续按住 General 配置的组合；先用 Convert Files 入口确认转换器可工作。

**视频抽音频失败**：没有音轨的文件不能提取音频。当前目标列表仍按扩展名生成。

**文档版式改变**：Pandoc/textutil 不保证 Office 精确排版；PDF → DOCX、Office 完整互转、OCR、电子书尚未实现。

**没有百分比或取消按钮**：当前提供忙碌/完成/失败反馈，进度和取消属于下一阶段。

**另一台 Mac 路线变少**：FFmpeg 等可选工具未随 DMG 分发；按 README 安装所需工具。当前包是本地 ad-hoc 签名，尚未做 Developer ID 公证。

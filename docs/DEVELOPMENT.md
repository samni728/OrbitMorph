# OrbitMorph 架构与开发

## 产品闭环

主用户是在 Mac 上频繁处理本地文件的人。闭环为 Finder 拖动 → 转盘选目标 → 后台本地转换 → 新文件。教程提供第一条可验证样本流程；没有账号、云端、支付、LLM 或用户文件遥测。

## 模块边界

| 层 | 对象 | 责任 |
| --- | --- | --- |
| UI/系统交互 | AppDelegate、SettingsView、教程、OverlayPanelController | 菜单栏、窗口、语言、玻璃、系统落点和状态 |
| 应用编排 | AppState、GlobalDragMonitor、JobCoordinator | 配置快照、修饰键、后台任务、目录访问 |
| Domain | FormatID、FileKind、ConversionRegistry、CompatibilityPolicy | 分类、真实路线、共同目标和用户禁用规则 |
| Services | ConversionEngine、ToolExecutor、OutputNamer | 批次、临时产物、排他提交、失败回滚 |
| Integrations | Adapters、DependencyResolver、ProcessRunner | 系统/外部工具、参数数组、超时和能力探测 |
| Data | AppSettings、SettingsStore、FolderBookmarkStore | Codable/UserDefaults、目录 bookmark |
| 分发/验收 | Tests、scripts、Resources | 真实矩阵、截图、样本、语言、签名、DMG |

不需要 API、数据库或插件 SDK。业务规则保持在 Core，外部命令通过独立 adapter 封装。

## 本地后端

ImageIO/PDFKit/Vision 负责系统图片、PDF 和文字提取；FFmpeg 负责媒体；ImageMagick 负责扩展图片；Pandoc/textutil 负责结构文档；7-Zip/系统工具负责归档；LibreOffice 负责 Office；Calibre 负责电子书。

命令使用 executable + arguments，不拼 shell。GUI 不依赖用户 shell PATH，按标准安装目录发现工具。LibreOffice 使用独立 profile 和源文件私有副本；Calibre 隔离配置与临时目录并检查PalmDOC/MOBI结构。电子书 PDF 使用 Qt offscreen 和禁用 GPU 的渲染设置，并指定系统中文字体。WMV/WMA/FLV/TS/3GP/CAF探测后还通过ffprobe校验真实流，缺ffprobe时隐藏对应输出；TS/3GP/FLV支持适用质量参数。

新增 backend 必须定义输入/输出契约、保真边界、异常行为及真实 fixture；扩展名不能替代内容结构检查。Office 测试回读工作表/幻灯片、中文、基础数值与公式；电子书回读两章正文，不能据此宣称图片/目录/元数据完全保真。

## 交互与输出事务

拖拽状态机为 idle → armed → ready → finish/cancel；新粘贴板与有效文件 URL 防止旧内容/框选误唤出。非激活 NSPanel、NSVisualEffectView 和 SwiftUI 构成浮窗，动画尊重 Reduce Motion。

唤出条件是修饰键加真实文件拖拽，不能仅凭按键展示。多屏定位使用鼠标所在屏幕，不固定主屏。超过八个项目时，中心按纵向数字1/2或1/2/3切页；文件拖到页码停留350ms后切换外圈，中心松手始终无转换动作。页码命中、停留切换与外圈目标命中需要共用几何规则，不能依赖文件拖拽期间未必触发的普通hover/click事件。

普通启动采用单实例：新实例激活现有实例后退出。截图CLI是独立渲染会话；它不得改写用户设置。升级期间仍运行的旧版本应先退出，避免不含新单实例逻辑的进程干扰验证。

AppState 初始化完成能力探测，早于任何 NSHostingView；UI 使用快照与缓存。禁止把冷启动子进程放在 SwiftUI body：Process.waitUntilExit 可能泵送主 run loop，造成布局重入。

JobCoordinator 保存设置/依赖快照，在后台顺序处理批次。产物先到目标目录的 `.OrbitMorph-UUID.ext`；提交前拒绝空文件，检查DOCX/PDF结构、图片可解码和目标音视频流；缺ffprobe的旧安装用FFmpeg短段解码并强制选择对应流，之后排他提交，已有名字追加后缀。支持时使用 RENAME_EXCL，否则 O_EXCL 复制与 fsync。失败只回滚本批次产物。归档拒绝穿越和链接成员。PDF文字提取逐页OCR并合并文本层，避免混合页正文遗漏；渲染考虑旋转页方向。

## 资源与语言

`Resources/Samples` 的 800×600 PNG 和带音视频流 MP4 用于教程；使用前复制到独立临时目录，避免输出写进签名app。`Resources/Sounds/segment-tick.wav` 是 PCM 反馈声音。`Localizable.xcstrings` 保持 JSON 格式，由应用直接加载，构建脚本复制到 app Resources，不依赖隐式 SwiftPM source bundle。

语言/外观截图参数只作用于本次渲染。素材为项目自建的非用户数据；不要把个人或企业文件放入测试/教程仓库。

## 开发与统一验收

```sh
swift build
swift test --scratch-path /tmp/orbitmorph-check
ORBITMORPH_FULL_MATRIX=1 swift test --scratch-path /tmp/orbitmorph-final-check
scripts/build-app.sh
scripts/capture-screenshots.sh
scripts/package-dmg.sh
scripts/verify-package.sh
git diff --check
```

矩阵需要完整本机工具组合，包括 LibreOffice 和 Calibre；普通测试默认跳过矩阵。测试数与路线数从最终日志/JSON 写入文档，不能引用历史版本数字代替。

`capture-screenshots.sh` 调用最终 app 的 wheel/settings/tutorial 自渲染 CLI，生成16张中英图片。转盘demo以PNG输入查询registry/policy的实际目标，不使用跨类别硬编码列表。保留原六条 gallery 路径，并记录 app 版本、二进制 hash、每张图语言/尺寸/scale/hash。设置/教程的关键中英图相同会报错；格式缩写相同的轮盘图可以相同。自渲染只证明真实view布局，不证明live blur、多屏拖拽、350ms停留切页或手势体验。

`verify-app-resources.py` 验证 PNG chunk CRC/尺寸、MP4音视频及真实解码帧、WAV非静音PCM和可解析中英语言目录；FFmpeg/ffprobe用于开发验收，不进包。`verify-package.sh` 验证版本/plist/ARM64/签名、只读挂载DMG、资源与二进制一致、source binary hash前后不变、Applications链接和卸载成功。

## 迭代边界

Now 是本地转换闭环、教程/中英文、真实产物和可复现包。Next 是执行进度/取消、内容级媒体过滤和更多 PDF 操作。Later 是专业 RAW/EXR/矢量与完整多帧编辑。Risk 是工具体积/许可、自带转换器策略、签名公证和跨 Mac 分发。

最终工作树验收：168 项测试、0 失败/跳过；554/554 路线通过；16 张截图、arm64 app 与 DMG 检查通过。[验收摘要](verification/release-summary.json)与[源码哈希清单](verification/source-manifest.json)关联本次代码。应用 binary SHA-256：`3fccc504d60e843db7e6525592ae89698ba9a6cf0f7f6ad7efea2d41f3c0461b`。

# OrbitMorph 架构与开发

## 产品闭环

主用户是在 Mac 上频繁处理本地文件的人。闭环为 Finder 拖动 → 转盘 → 选择目标 → 后台转换 → 新文件。输入输出都在用户电脑；没有账号、云端、支付或 LLM。

## 模块边界

| 层 | 对象 | 责任 |
| --- | --- | --- |
| UI / 系统交互 | AppDelegate、SettingsView、OverlayPanelController、DragReceivingView | 菜单栏、窗口、转盘、系统落点和状态展示 |
| 应用编排 | AppState、GlobalDragMonitor、JobCoordinator | 配置、修饰键状态、任务快照、目录访问及后台执行 |
| Domain | FormatID、FileKind、ConversionRegistry、CompatibilityPolicy | 分类、真实路线、共同目标和用户禁用规则 |
| Services | ConversionEngine、ToolExecutor、OutputNamer | 批次、工具、临时输出、排他提交与回滚 |
| Integrations | Adapters、DependencyResolver、ProcessRunner | 框架/工具调用、绝对路径、参数数组、超时、能力探测 |
| Data | AppSettings、SettingsStore、FolderBookmarkStore | UserDefaults、Codable、目录 bookmark |
| 验证 / 分发 | Tests、scripts、Resources | 回归/真实矩阵、截图、图标、签名、DMG |

当前不需要 API 服务、数据库或插件 SDK。业务规则放 Core，外部命令通过 adapter 封装。

## 拖拽和玻璃 UI

`GlobalDragMonitor` 监听鼠标/修饰键；`FileDragPasteboardGate` 要求 session 有新粘贴板与有效文件 URL，避免 Finder 框选或旧内容误唤出。状态机为 idle → armed → ready → finish/cancel，修改组合可换模式，取消后恢复 idle。

落点由 `NSDraggingDestination` 接收，按统一半径和页内扇区命中。浮窗是非激活 `NSPanel`；active/behindWindow 的 `NSVisualEffectView` 提供原生磨砂，SwiftUI 绘制分区，Core Animation 做整体缩放、旋转和淡入淡出。

## 后台任务与输出事务

`JobCoordinator` 取设置与依赖快照，在后台运行 Engine/ToolExecutor。当前一次执行一个用户批次，批次内逐个文件处理。

命令使用 `ProcessInvocation(executable, arguments)`，不拼接 shell。GUI 不依赖 shell PATH；外部进程默认超时 900 秒。

输出先到目标目录的 `.OrbitMorph-UUID.ext`，验证后排他提交。支持时使用 `RENAME_EXCL`，否则 `O_EXCL` 复制与 fsync；已有名字增加后缀。批次失败回滚本批次产物，PDF 逐页输出同样遵守约定。归档拒绝穿越路径和链接成员，保留归档根内容。

## 新格式接入

1. 定义 FormatID、扩展名别名与类别，复合后缀如 `.tar.gz` 用文件 URL 识别。
2. 明确可读输入/可写输出、依赖与保真边界，实现 adapter。
3. 注册实际路线，缺依赖/编码器就隐藏；能力检测应缓存。
4. 先写失败测试再实现，覆盖损坏输入、Unicode、重名与失败回滚。
5. 给全矩阵增加夹具与解析方法，确保每条注册路线均覆盖。
6. 更新工具适用范围、设置、指南、报告、截图和包。

SVG 是输入专用；字幕独立 subtitle，不能混入 Pandoc/textutil。格式列表不能替代真实产物验收。

能力探测在 AppState 初始化时完成，早于创建任何 NSHostingView；输出格式保存为不可变快照，随后 UI 查询只命中探测缓存。不要在 SwiftUI body 内启动首次探测子进程：macOS 的 `Process.waitUntilExit` 可能泵送主 run loop，导致布局重入和 AttributeGraph 崩溃。

## 开发与验证

```sh
swift build
swift run OrbitMorph
swift test
ORBITMORPH_FULL_MATRIX=1 swift test

# 独立构建目录避免共享 SwiftPM 锁
swift test --scratch-path /tmp/orbitmorph-dev-check
```

全矩阵依赖本机 Homebrew FFmpeg/ffprobe、ImageMagick、Pandoc、7zz 及系统工具，生成小文件并逐条转换；普通测试默认跳过矩阵。自动接收器/状态机验证不能代替真实 Finder 手势与动画体验。

```sh
scripts/build-app.sh
scripts/capture-screenshots.sh
scripts/package-dmg.sh
scripts/verify-package.sh
git diff --check
```

截图来自最终 app 的自渲染模式，用于布局检查；不录制背景模糊/手势动画。README 图片在 `docs/screenshots/`，日志与矩阵在 `docs/verification/`。

DMG 验证检查 plist、ARM64、资源、签名、checksum、挂载 app 与原 app 的 binary hash、Applications 链接及卸载成功。正式分发还需 Developer ID 公证和工具分发策略。

## 配置与诊断

UserDefaults 保存 Codable 设置，旧设置缺新字段时填默认值；bookmark 记目录访问。About 显示转换器路径，窗口显示任务状态，进程输出记录执行结果。没有用户文件遥测或自动上传。

排查优先使用可分享的生成夹具；不要把个人/企业文件加入测试仓库。

## 后续迭代

已有 V2 文档含首次教程、仅菜单栏启动、中英文与更多格式，本轮只落实五个格式。Next 优先引导、本地化、进度/取消及内容级媒体过滤；Office/PDF/OCR/电子书按独立后端逐批迭代。见 `FORMAT_COVERAGE.md`。

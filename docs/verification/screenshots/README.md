# OrbitMorph app 截图

这些图片通过实际编译的 app 自带渲染入口生成，不是设计稿或生成式 UI 图片。

| 文件 | 内容 |
| --- | --- |
| wheel.png | 演示转盘、当前高亮和中心提示；演示包含跨类别格式，真实目标按输入过滤 |
| general.png | 外观、登录启动、反馈和拖拽修饰键 |
| formats.png | 输出格式与实际参数 |
| compatibility.png | 分类与兼容矩阵，可横向滚动 |
| folders.png | 默认/按类别的输出目录，可纵向滚动 |
| about.png | 版本、原创图标、本机转换器检测 |
| metadata.json | 捕获时间、app 版本、二进制与截图 SHA-256、图片尺寸 |

重新生成：

```sh
scripts/build-app.sh
scripts/capture-screenshots.sh
```

通过 `APP_PATH` 或 `OUTPUT_DIR` 可指定不同 app/目标目录。脚本要求 macOS 和 Python 3，顺序启动 app 的截图模式、检查 PNG 头与尺寸并保存 metadata。

截图为转盘/设置内容区域，背景透明和桌面磨砂的实时效果不能由自身 view 缓存截图证明；旋转与拖拽动画也需要实际运行观察。全局 Shift / Option+Shift 手势仍按开发进度中的人工验收状态记录。

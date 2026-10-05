# OrbitMorph 1.2.1 app截图

图片通过最终编译app的自渲染CLI生成，不是设计稿或生成式UI。原gallery路径保留，英文与中文各有五个设置页面、转盘的两页及 PNG/MP4 两个教学演示，总计18张。

| 文件 | 内容 |
| --- | --- |
| wheel.png / wheel-zh.png | English/中文PNG输入转盘，目标来自当前registry/policy与本机工具，非跨类别演示列表 |
| wheel-page-2.png / wheel-page-2-zh.png | 同一PNG输入的第2页，其余转换目标与中心页码2高亮 |
| general.png / general-zh.png | 语言、外观、登录启动、反馈与修饰键 |
| formats.png / formats-zh.png | 输出格式和适用参数 |
| compatibility.png / compatibility-zh.png | 分类及兼容矩阵 |
| folders.png / folders-zh.png | 默认/分类输出目录 |
| about.png / about-zh.png | 版本、原创图标与转换器路径 |
| tutorial-en.png / tutorial-zh.png | 第一步转换教程 |
| tutorial-tools-en.png / tutorial-tools-zh.png | MP4 工具教学，转盘仍在教程内部 |
| metadata.json | 捕获时间、app版本/build、binary hash、每张图语言/尺寸/scale/hash |

```sh
scripts/build-app.sh
scripts/capture-screenshots.sh
```

支持APP_PATH/OUTPUT_DIR/EXPECTED_VERSION。CLI契约：`--render-wheel=... --wheel-page=1|2`、`--render-settings=... --section=...`、`--render-tutorial=... --tutorial-step=conversion|tools --tutorial-preview`，共同指定`--language=en|zh-Hans --appearance=dark --style=glass`。

尺寸按实际Retina比例读取：wheel310×310pt、settings850×580pt、tutorial680×520pt，允许1×/2×/3×。脚本校验PNG CRC/尺寸，设置/教程的关键中英图完全相同会失败；所有产物验证后再更新gallery，不用旧图片伪装本次截图。

设置与教程图片使用与亮/暗主题匹配的静态底色，避免透明PNG在查看器中变黑；实际运行窗口仍使用原生玻璃材质。格式转盘选中格式时仅显示通用文件缩写（例如WEBP），中英文图片可以相同；工具名称与未选中提示会按语言翻译。超过八个项目时中心显示纵向页码，两页上1下2，三页1/2/3；运行中拖到页码停留350ms后切换外圈，中心松手不转换。

CLI只证明真实view渲染结果，不能证明live blur、鼠标屏幕定位、单实例激活或真实修饰键拖拽/停留翻页行为；这些需要另行运行验收。

最终截图校验：18/18 PNG 通过，1.2.1 build 1。第 1/2 页图不同，设置/教程中英图不同，完整捕获前后用户设置 hash 一致。最终 binary SHA-256：`d56d574adcf127797cb22d56ca9e2a810320aa5296838f17519d2a93b1302b1d`。详见 `metadata.json` 与 `../verification/screenshot-preferences.json`。

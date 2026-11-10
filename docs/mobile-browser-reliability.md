# 手机浏览器人物与加载稳定性修复（本地，2026-11-02）

用户反馈设备为 iPhone 13 Pro Max，Safari 和 Chrome 均偶发人物消失、使用中刷新后重新初始化，首次加载很慢。本轮没有部署线上，也没有把桌面浏览器模拟结果当作 iOS 真机验收。

## 排查证据

- 线上人物资源清单为 89 个分片，容器解压后共 92,460,600 字节（88.18 MiB）；原始 GLB 为 153,334,024 字节，425,144 个三角形、52 个表情形态。COS 存储不会消除客户端下载、解码、上传 GPU 的成本。
- 旧启动路径会读取全部已发布课程、提示文档和课程插图，再宣告初始化完成。现在只读取公共提示和当前课程；选择其他课程时再读取其教学数据，插图交由使用位置读取。
- 旧手机默认继承高画质 120 fps；现有 WebGL 帧快照的原始 ui.Image 句柄没有对应释放。实际 OffscreenCanvas 上也缺少上下文丢失监听。
- 没有发现普通渲染、页面可见性变化时主动刷新页面的代码。浏览器是否因内存压力重载标签页，尚无用户真机日志证实。

## 实现

- 手机 Web 默认中画质，目标 30 fps，渲染比例 0.85，关闭中画质阴影。高画质手机也限制为 30 fps；桌面/原生预设保持原行为。
- 场景放入 RepaintBoundary；切到后台停止场景自动绘制，登录表单遮挡时暂停隐藏人物的 tick。
- WebGL 快照的原始图像句柄延后两次 Flutter 帧回调释放；退出场景时释放剩余句柄。诊断可观察 frameImagesHeld。
- 手机纹理从已有 mip 链选择不超过 1024 的级别，保留其余 mip。未改人物网格、骨架和表情；桌面与只有基础级的纹理保留原数据。
- Web 二进制场景读取分块让出事件循环，优先使用浏览器 DecompressionStream 解压；旧浏览器保留回退。已覆盖非对齐分片头的 Float32 读取回归，避免对齐复制引入另一份大缓冲。
- 资源分片读取和全模型校验分段让出主线程；保留每片及整体 SHA-256 校验。离开时关闭下载客户端，避免取消后仍回落加载大模型。场景实例创建完后释放导入模板缓存。
- 监听实际人物 OffscreenCanvas 和可见 WebGL 上下文丢失。发生中断时停止人物和录音/播放、保留学习状态并提示恢复。只有用户点击“恢复页面”，且当前账号的学习位置和当前课程均保存成功，才刷新；保存失败可重试。没有新增自动刷新。
- App 中仍无 B1.01 播放入口；正式课程发布、音频和独立掌握判定门槛保持原有边界。

## 验证与限制

- Flutter 聚焦回归 45 项通过：手机预算、按需课程加载/重试、分块解析/对齐/损坏校验、图像句柄释放、手动恢复/保存失败、账号学习位置，以及原有场景/目录/教学/同步/登录交互。
- Flutter analyze --no-pub 无问题，git diff --check 通过。
- Release Web 构建成功：`tools/flutter-scene.ps1 build web --release --no-web-resources-cdn --no-pub --base-href /scene/ --no-wasm-dry-run --dart-define=SCENE_DIAGNOSTICS=true`。已有 CupertinoIcons 字体族警告不阻止 JavaScript 构建。
- 本地 Chromium 使用 iPhone 用户代理、428×926 和 926×428 视口；人物可见，目标 30 fps，采样约 29.7–30.1 fps，frameImagesHeld 稳态为 0。横竖屏截图保存在开发聊天 outputs 中。这只验证移动策略和布局，不能证明 Safari、手机 GPU 或 iOS 标签页回收已通过验收。
- 冷启动人物数据仍为 88.18 MiB；本轮降低初始化阻塞和运行内存负担，未交付新的低体积人物模型，不能承诺首次下载已变快到可接受程度。模型资源体积仍是后续优化项。
- 实际 iPhone 上的上下文丢失、系统强制重载、弱网冷启动、长时间教学/录音均待真机复测；当前修复尚未上线。

WebGL 上下文丢失机制参考：[Khronos HandlingContextLost](https://wikis.khronos.org/webgl/HandlingContextLost)、[WebGL 1.0 specification](https://registry.khronos.org/webgl/specs/1.0/)。

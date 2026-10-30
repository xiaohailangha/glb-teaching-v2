# Flutter Scene 人物教学验证

**r6 成人首课已发布**：[打开网页](https://49.233.179.83/scene/?r=6)，点击左上角“成人入门 · 认识水果”。完整包含 apple / banana 图片认识、发音练习、听辨、看图回忆、an apple / a banana、延后复习和本节记录，支持暂停/刷新后继续。34 项 Flutter 测试、音频回归、隐藏浏览器完整走课及 8 组线上检查通过；真人录音与用户整课体验仍待反馈。本轮不更新 Android，详见 `../docs/flutter-scene/adult-fruit-course-r6-2026-10-30.md`。

**r5 手机反馈与 Android 更新：用户已复测 Web 并确认“动作和声音都可以”。新引擎 Android 0.2.0+5 ARM64 release 已构建，模型和男童语音内置，签名与包内资产校验通过；[下载测试 APK](https://49.233.179.83/downloads/glb-scene-0.2.0-r5-arm64.apk)。与旧包可并存，原生实机表现另行验证，详见 `../docs/flutter-scene/android-r5-2026-10-30.md`。**

**2026-10-30 r5 候选已部署**：点词仅播放目标词，固定课件与音标统一为云小洋男童声并内置；动作改为有界短段连续表演。29 项 Flutter 测试、2 项音频资产回归和 7 组线上资源检查通过。本轮隐藏 IAB 不可用、无连接真机，动作观感、音标清晰度和手机音频仍待复测，尚未打 Android 新包。详见 `../docs/flutter-scene/motion-audio-r5-2026-10-30.md`；[男童声试听](https://49.233.179.83/scene/voice-review.html)。下文 r4/r3 记录为历史证据。

独立测试入口：[Flutter Scene 测试页](https://49.233.179.83/scene/)，直接访问，无账号密码。根目录应用及[原版测试页](https://49.233.179.83/)保留原 Flutter + Three.js 版本。Android 模型继续内置安装包。

本目录使用 Flutter **3.47.9** / Dart **3.13.7**，`flutter_scene` **0.24.3**。SDK 独立放在项目 `work/flutter-scene-sdk`，不升级原来的 `D:\flutter`。Web 后端为 flutter_scene 的 WebGL2；原生后端为 Flutter GPU，不能用 Web 测试结果证明原生 Vulkan/Metal 的性能。

## 从私有仓库恢复

```powershell
git lfs install
git clone https://github.com/xiaohailangha/glb-teaching-v2.git
cd glb-teaching-v2
git switch feat/flutter-scene
git lfs pull
git clone --depth 1 --branch 3.47.9 https://github.com/flutter/flutter.git work/flutter-scene-sdk
.\tools\flutter-scene.ps1 pub get
.\tools\flutter-scene.ps1 analyze --no-pub
.\tools\flutter-scene.ps1 test --no-pub
.\tools\flutter-scene.ps1 build web --release --no-web-resources-cdn --no-pub --base-href=/scene/ --no-wasm-dry-run
```

已验证 SDK 提交为 `c197ca5199e9ee5661e865596c9c07294dfab51c`。Windows 包装脚本临时使用 `V:`，不要同时运行两个 Flutter 包装脚本；需要本机 Android SDK/JBR 时按脚本中的路径配置。SDK、Pub 缓存与生成的 shader/model 包不提交。模型原件用 Git LFS，构建 hook 将其预处理成 `.fsceneb` 并压缩 GPU 贴图；原生包加载内置资源，不依赖 COS 模型下载。

本地先启动根目录语音后端 `node server.mjs`，再运行 `node tools/scene-preview-server.mjs`，访问 http://localhost:5303/scene/ 。缺少本地凭据时使用内置示范音频；真实腾讯配音/ASR/评测需要本机 `.secrets`，不得提交到 Git。

## 已移植

- 保留 Flutter 教学界面、10 个单词、独立音标块和中文释义、慢速/重播/切词、近景和画质设置。
- Dart 教学导演层、apple 成人及三个儿童年龄样板、听辨/帮助/回忆/尝试反馈；“我读好了”不等于评分或掌握。
- 原模型的教学和情绪骨骼动画、52 个脸部变形通道、12 种情绪、连续眼神/身体/头发动作。
- 腾讯配音与同一音频对应的口型时间轴；Dart 浏览器音频适配保留同一音频元素，并在原始点击中解锁 Safari 播放。快速切换会丢弃旧会话。
- 点击跟读时的 PCM16 录音上传、ASR/SOE 接口；浏览器/真机麦克风链路仍需用户实测。
- 网页新模型独立使用 89 个私有 COS 分块、SHA256 校验、按内容版本缓存；云资源失败时回退同版本站内文件，不自动刷新页面。

## 当前取舍和验证边界

`scene-0.2.0-r4`：修复裤子/裤绳/标签中误绑到手臂和手指的权重；加载时应用独立校验绑定，不更换原 89 块模型。普通教学按意图选择完整骨骼姿态，停止循环扫过整个表演，去掉无目的的周期转身并缩短动作/脸部迟滞。源模型及 GLB 的中性眼位本身相对眼眶偏鼻侧，已用两侧一致的原 Gaze 修正校准默认表面，同时取消独立转眼球与眼皮变形的冲突。26 项 Flutter 测试、analyze 和 Web release 通过；CPU 三角形对照及视觉验证边界见 `../docs/flutter-scene/motion-fix-r4-2026-10-30.md`。用户确认 r3 白边已消失；r4 手机眼位、完整表情和动作观感待复测。

角膜在 WebGL 屏幕取色路径下出现黑眼，已通过移除角膜的对照画面定位。现用薄透明角膜与跟随视线/光线的几何高光，保留真实虹膜与眼白；未启用屏幕空间折射。没有为了性能删掉原模型网格或表情。

vendored 引擎补丁把 GPU 活跃表情预算从 8 提至 64、贴图维度上限从 2048 提至 4096，使用 RGBA16F 存储位置/法线变形，并拒绝本模型意外退回 CPU 变形。补丁清单见 `vendor/flutter_scene/LOCAL_PATCHES.md`。

已通过 23 项 Flutter 测试（含 341 个原 JS 表演曲线采样对照，以及真实 Storm 绑定数据的转头、动画过渡和额外重绘回归）、analyze、Web release 构建；根目录既有 55 项 Node 回归测试通过。线上检查见 `../docs/flutter-scene/web-verification.json` 和 `browser-verification.json`。用户反馈 r2 在 iPhone 浏览器达到 50 FPS 以上，同时提供眼球、头发错位和白边截图；这是用户反馈，不是本机真机测试。

`scene-0.2.0-r3` 修正 vector_math 的 Quaternion.rotated 与 Node 渲染矩阵旋转方向不一致；眼球、头发位置改用相同主动旋转。平滑头部时，附属关节使用同一个头部矩阵差量；眼球中心与发根保留头部绑定位置，避免位置插值穿过转头轨迹内部，眼球转动和发梢摆动继续保留。每次引擎 prepass 在动画前恢复附加姿态，不依赖 UI Ticker。人物与相同灰色渐变在 GPU 内合成不透明图像后再抗锯齿，减少透明画面跨浏览器合成的边缘问题；Safari 白边是否消除仍需原手机复测。详细证据见 `../docs/flutter-scene/visual-fix-2026-10-30.md`。

`scene-0.2.0-r2` 的帧率取自引擎实际产生绘制的屏幕帧，GPU 复用上一帧、等待资源或只有 Ticker 回调时不计入。计数不是 GPU 耗时，原生还需 profile/真机验证。

先完成手机 Web 对比，再打本目录 Android 包。尚无此渲染器的 Android release 构建或真机录音/性能通过记录。当前 `android/` 已声明 Internet、按需麦克风及 Flutter GPU；测试包使用单独应用 ID，便于以后与旧包并存。

## 维护

`node tools/generate-scene-tracks.mjs` 生成 Dart 表演表，`node tools/generate-scene-parity.mjs` 生成原实现对照样本；修改模型后另运行 `node tools/generate-storm-clothing-bindings.mjs`。修改后运行 Flutter format/analyze/test，再观察画面和浏览器错误。

发布顺序：构建 Web → 必要时 `node tools/publish-scene-assets.mjs` 上传新模型分块 → `node tools/deploy-scene-preview.mjs` → `node tools/test-scene-preview.mjs`。部署脚本限定现有腾讯实例，仅更新 `/scene/`、独立模型清单接口及其配置，并保存回滚备份；不操作 ExtraVM。

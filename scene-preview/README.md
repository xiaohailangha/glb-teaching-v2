# Flutter Scene 人物教学验证

独立测试入口：https://49.233.179.83/scene/ ，直接访问，无账号密码。根目录应用及 https://49.233.179.83/ 保留原 Flutter + Three.js 版本。Android 模型继续内置安装包。

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

角膜在 WebGL 屏幕取色路径下出现黑眼，已通过移除角膜的对照画面定位。现用薄透明角膜与跟随视线/光线的几何高光，保留真实虹膜与眼白；未启用屏幕空间折射。没有为了性能删掉原模型网格或表情。

vendored 引擎补丁把 GPU 活跃表情预算从 8 提至 64、贴图维度上限从 2048 提至 4096，使用 RGBA16F 存储位置/法线变形，并拒绝本模型意外退回 CPU 变形。补丁清单见 `vendor/flutter_scene/LOCAL_PATCHES.md`。

已通过 18 项 Flutter 测试（含 341 个原 JS 表演曲线采样对照）、analyze、Web release 构建；根目录 55 项 Node 回归测试通过。线上检查见 `../docs/flutter-scene/web-verification.json`。桌面画面、配音与待跟读状态已观察；不能据此宣称 S98Pro 或 iPhone 的发热/帧率已改善。

先完成手机 Web 对比，再打本目录 Android 包。尚无此渲染器的 Android release 构建或真机录音/性能通过记录。当前 `android/` 已声明 Internet、按需麦克风及 Flutter GPU；测试包使用单独应用 ID，便于以后与旧包并存。

## 维护

`node tools/generate-scene-tracks.mjs` 生成 Dart 表演表，`node tools/generate-scene-parity.mjs` 生成原实现对照样本。修改后运行 Flutter format/analyze/test，再观察画面和浏览器错误。

发布顺序：构建 Web → 必要时 `node tools/publish-scene-assets.mjs` 上传新模型分块 → `node tools/deploy-scene-preview.mjs` → `node tools/test-scene-preview.mjs`。部署脚本限定现有腾讯实例，仅更新 `/scene/`、独立模型清单接口及其配置，并保存回滚备份；不操作 ExtraVM。

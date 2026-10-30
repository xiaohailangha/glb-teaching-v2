# 本轮验证记录

日期：2026-10-28。

- Flutter 3.35.7 / Dart 3.9.2，项目根目录 `D:\AI语言训练\v2`。
- `flutter analyze --no-pub`：通过，无问题。
- `flutter test --no-pub`：7 项通过。包括切词时忽略迟到事件、慢速重启与重复次数、就绪前禁止播放，以及 1678×856、844×390、390×844、320×568 四种尺寸的页面和正常/慢速操作栏无溢出。
- `flutter build web --release --no-web-resources-cdn --no-pub`：通过。Flutter 有未使用的 CupertinoIcons 字体声明警告，未影响构建。
- `npm run check`：Three.js 场景与预览服务脚本语法通过。
- Chrome 中点击 APPLE 播放：HTMLAudioElement `paused=false`，`playbackRate=1`，播放时间推进。
- Chrome 中切换 fish，切换慢速并播放：`paused=false`，`playbackRate=0.75`，时长约 1.544 秒。口型时间源为该音频的 `currentTime`。
- 已目视核对灰色整屏背景、左侧人物近景、右侧白字排版，以及操作栏隐藏后的画面。
- 桌面 Chrome 当前观测约 20 FPS；渲染器为 NVIDIA GTX 1050 Ti / ANGLE Direct3D11。此结果尚不满足稳定 60 FPS 的目标，不能据此承诺手机性能。
- Android APK 构建曾进入 Gradle 阶段，但等待期间未完成；本轮未取得可验证 APK。无已连接的 Android/iOS 真机，未做移动端性能或音频验证。iOS 未在 Windows 上构建。
- 当前是免费 Snow 的固定 morph 姿态混合原型，未接入 Storm，也未验证 Storm 导出。面部口型未逐音素教学标定，不包含录音评分。

未修改用户当前 Blender 中打开的场景；模型转换使用独立后台 Blender 进程。

## 2026-10-28 后续：60 FPS 与自然动作优化

- 重新连接 Chrome 后完成完整 Flutter 页面的前台测试。1280×900 和 844×390 视口均持续说话 30 秒：60 FPS、帧间隔 P95 16.8 ms、零个超过 25 ms 的慢帧。实际 JSON 位于 `docs/performance-reports/`；更大桌面视口亦通过。
- 更正先前约 20 FPS 的结论：后台调度影响了该读数。用户完成的原始独立人物页前台测试也是 60 FPS；不能把原始模型的性能能力描述为只能达到 20。
- 开启裁剪后，当前视角绘制调用由 20 降到 16。音频进度更新与课程状态分离，隐藏操作栏不再挂载 HUD，避免播放期间重建整个单词区。
- 口型使用连续边界过渡与闭唇优先；短辅音、慢速和停说复位均有测试覆盖。采用非对称眨眼、缓慢姿态转换和随示范变化的轻微动作。
- 修复 TH/L 舌头控制器，保留面部变形法线。打包验证确认全部 15 个网格的基础顶点位置与原模型完全相同；TH/L 舌头形状差异约 8.83 mm。
- `flutter analyze` 通过；Flutter 测试 8 项、Node 动作与计时测试 8 项通过；Web release 构建通过。
- 手机实际设备、Android APK 以及 iOS 的运行与性能仍未验证。口型仍待发音教师标定。

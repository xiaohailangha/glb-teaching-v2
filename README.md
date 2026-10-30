# glb模型能力

全部项目内容位于 `D:\AI语言训练\v2`。

2026-10-30 新渲染器验证：`scene-preview/` 为独立 Flutter GPU + flutter_scene 试验版，Web 入口 **[Flutter Scene 测试页](https://49.233.179.83/scene/)**，无需登录。先对比 Web，再打 Android 包；原生安装包仍内置人物模型。运行说明和未验证项见 [scene-preview/README.md](scene-preview/README.md)。私有源码仓库为 `xiaohailangha/glb-teaching-v2`，`main` 保留旧版基线，`feat/flutter-scene` 维护验证版。

2026-10-30 COS 更新：Storm 模型已通过北京私有 COS 分发，浏览器按模型版本缓存，失败回退服务器。桌面实测首次模型下载约 5.3 秒、再次打开零模型网络下载；这不是手机速度或帧率保证。配置、回滚和验证见 `docs/cos-integration/README.md`。

2026-10-30：已部署私人 Web 测试版到新购腾讯云服务器，入口 **[原版测试页](https://49.233.179.83/)**，按用户要求已取消账号密码。维护、HTTPS自动续期、真实下载耗时及验证边界见 `docs/cloud-deployment/README.md`。原ExtraVM翻墙VPS未改动。

最新课程表演入口：**演示库 → 课程表演 · apple → 成人零基础 / 儿童年龄版本**。已接入与教学阶段和用户作答联动的眼神、表情、身体动作，以及帮助、回忆和反馈分支。当前完整交互样板为 apple；课程全量适配设计与未完成的专用动作见 `docs/curriculum/人物教学表演适配方案.html`，最新验证见 `docs/integrated-teaching.md`。下文原始表演与模型介绍保留为项目历史。

## 预览

双击 `启动预览.cmd`，或在本目录执行 `npm start`，打开 http://localhost:5296/ 。预览使用已编译的 Flutter Web，运行时无需在线字体或 CDN。

画面参考 `docs/layout-reference.png`：灰色整屏渐变、左侧人物近景、右侧白色大字。点击单词播放；点击空白显示操作栏，5 秒后自动隐藏。左右滑动或方向键切词，空格播放，Esc 隐藏操作栏。横屏最接近参考图。

当前人物为用户提供的 **Storm v1.1**，默认加载 `storm-performance.glb`；Snow 原文件保留为历史备份，不再作为运行人物。已接入腾讯云超自然大模型 2.0 配音、实时 ASR V2 和新版口语评测，服务端密钥仅保存在本机 `.secrets/`。转换记录见 `docs/storm-integration.md`，语音接入与限制见 `docs/tencent-integration.md`。

「情绪演示」包含开心、伤心、沮丧、害怕、生气、惊讶、好奇、疑惑、害羞、自豪、厌恶、释然，共 12 段无声表演，每段 6 秒。可选择情绪、重播、停止，或全部连播 72 秒；身体和面部同步表演。原版正式眼球及角膜保留。构建与验证见 `docs/emotions.md`。

新增「10 秒教学表演」按钮。预览 `http://localhost:5296/?demo=1` 从半身构图开始：招呼、看向 APPLE、示范、邀请跟读、倾听。人物使用全幅透明 3D 画布，位于页面左侧；文字在前景，人物和手臂可以跨过中线，只有页面边缘会裁切。页面标题和移动端显示名称均为「glb模型能力」。

## 项目架构

```text
lib/
  app.dart                         Flutter 应用与主题
  core/avatar/                     Web iframe / 原生 WebView 适配
  features/lesson/
    domain/                        10 个教学单词
    application/                   播放、切词、循环、速度与事件状态
    presentation/                  全屏教学页面
assets/avatar/
  models/storm-performance.glb      128 关节、教学和情绪骨骼动画、52 个变形通道
  models/snow*.glb                  历史备份，不再打包进应用
  audio/                           本地语音与 viseme 时间线
  avatar.js                        Three.js 渲染、表情、音频同步
  vendor/                          本地 Three.js 及许可
source-models/                     官方压缩包、Blender 原文件与贴图
tools/                             模型转换、语音生成、Flutter 构建脚本
android/ ios/ web/                 Flutter 平台工程
test/                              播放状态与竞态测试
docs/                              参考图、模型报告与验证记录
```

Flutter 负责页面与课程状态。Android/iOS 用 WebView，Web 用 iframe 加载同一份本地 Three.js 场景。指令与事件通过 JSON 通信。原生端通过应用内 loopback HTTP 服务读取打包资源，不需要远程模型服务器。

Storm 包含 128 个运行时骨骼关节，10 秒教学动作和 72 秒情绪动作。由 Storm 自身控制骨骼重新烘焙；口型、表情、眼神和眨眼单独混合。普通教学配音由腾讯云生成，音素时序使用该音频的 SOE 对齐结果；固定历史演示保留原配音。现有身体表演通过教学阶段选择和混合已编排动作，尚不是任意文本的语义动作生成系统。

## 开发

### iPhone 局域网预览与横屏

不同网络可双击 `启动手机外网预览.cmd`，它通过 Cloudflare Quick Tunnel 创建临时 HTTPS 入口，链接自动附带 12 小时访问凭据并保存在 `work/tunnel/access-link.txt`。复用前会检查真实公网入口和语音接口，不能仅凭进程存在认定可用。连接保持时复用地址，重启隧道会换地址。12 小时只指访问凭据有效期，临时服务没有在线时长保证。使用 Safari 打开完整链接后，验证信息转入 Secure/HttpOnly Cookie。仅编译后的网页资源和三个腾讯语音 API 可访问；源文件、凭据、诊断上传不开放。测试结束双击 `关闭手机外网预览.cmd`，只关闭本项目隧道与网关，保留本机开发服务。电脑休眠或断网会中断测试。HTTPS 允许申请麦克风，实际 iPhone 录音与性能仍需真机验证。公网接口回归检查：`node tools/test-public-preview.mjs`。

原生启动时限制为左右横屏，iPhone/iPad 的 Info.plist 同步限制方向，Android Activity 使用 sensorLandscape。Web manifest 声明 landscape；Safari 不支持可靠的网页强制方向锁，手机竖屏时显示横屏提示，需要关闭系统竖排方向锁定并横持。iOS 安装包仍需要本地或云端 macOS/Xcode 编译和签名，此次没有完成 iOS 真机构建。

在电脑启动 `npm start` 后，运行 `node tools/lan-preview.mjs <电脑的局域网 IPv4>`。临时入口绑定指定内网地址的 5298 端口，完整手机链接保存在 `work/lan-preview-session.json`，12 小时有效；手机连接同一路由器网络，用 Safari 打开完整链接。电脑需保持运行。此入口以临时会话验证访问，转发页面、模型与腾讯教学配音，密钥仍仅留在本机服务。没有开启公网隧道。

HTTP 局域网测试覆盖画面、表情、动作、播放与口型；麦克风跟读需可信 HTTPS 或原生 App，不在此入口开放。Safari 测试结果不能替代原生 WKWebView 性能验证。网页构建与 Flutter analyze 已通过；本机验证入口鉴权、方向配置、模型 Range 读取和腾讯 apple 配音均通过，真实 iPhone 的网络连通与帧率仍待手机测试。

本机 Flutter 位于 `D:\flutter`。使用脚本临时映射 ASCII 路径，避免 Flutter shader 编译器处理中文路径失败；实际文件始终留在本目录。脚本暂用 V:，构建结束自动移除映射，不可同时运行两份。

```powershell
& tools/flutter.ps1 pub get
& tools/flutter.ps1 analyze --no-pub
& tools/flutter.ps1 test --no-pub
& tools/flutter.ps1 build web --release --no-web-resources-cdn --no-pub
& tools/flutter.ps1 build apk --debug
```

重新烘焙当前人物需本机 Blender 5.2，在独立后台 Blender 运行 `tools/export_storm.py`。不要在用户已打开且未保存的 Blender 场景中执行。`export_snow.py` 和本地声音生成脚本保留用于历史素材维护。

模型导出会自动压缩不需要的变形法线缓冲；`tools/validate_avatar.py` 检查几何保持、数据引用与 TH/L 舌头差异。`npm test` 验证口型连续性、闭唇、停说复位与帧率无关的动作积分。面部控制在 `assets/avatar/motion.js` 中。

性能复测入口为 http://localhost:5296/?perf=1 ，操作方法和验收记录见 `docs/performance.md`。完整 Flutter Web 页面在 1280×900 与 844×390 视口的 30 秒说话测试均为 60 FPS，P95 为 16.8 ms，无超过 25 ms 的慢帧。此为桌面 Chrome 结果，手机真机尚未验证。诊断只在该模式显示，普通页面保持简洁。

上述是旧版记录。新版全幅骨骼与面部表演的验证见 `docs/teaching-performance.md`：在本机隐藏预览中，完整 Flutter 页面 1280×720 连续表演 30 秒为 60 FPS、P95 16.8 ms、超过 25 ms 的帧为 0。最新视频位于 `docs/snow-expression-10s.mp4`；本版重做了笑容、脸颊、眼睑和左右眉毛的配合，保留正常身体表达。

## 素材许可与边界

Storm Rig (CC) Blender Foundation | studio.blender.org

- 当前模型来源：https://studio.blender.org/characters/storm/v1/
- 历史 Snow 素材：Snow Rig (CC) Blender Foundation | studio.blender.org，https://studio.blender.org/characters/snow/v4/
- 许可：https://creativecommons.org/licenses/by/4.0/
- 修改：贴图压缩与图集、材质简化、表情及姿态烘焙、GLB 格式转换。
- 应用中可通过操作栏的信息按钮查看署名。
- Three.js MIT 许可保存在 `assets/avatar/vendor/THREE-LICENSE.txt`；字体 OFL 保存在 `assets/fonts/OFL.txt`。

当前为 10 单词的音频和口型同步验证。本机 Web 已接入按钮录音、识别、跟读评测；尚未完成真人和儿童评分校准、用户系统或课程后台。口型尚未由发音教师逐音素校准，不能当作精确舌位教学成品。Android 真机与 iOS 尚未验证，不能由桌面浏览器结果推断手机帧率。上面的 Snow 性能记录是历史记录，Storm 本次结果单独保存在 `docs/storm-integration.md`。



2026-10-29 临时入口故障修复：localhost.run 的匿名域名在 SSH 进程仍存活时由 31beca33ebe700.lhr.life 变为 c3b833da6f48cc.lhr.life，旧域名返回 502 no tunnel。已停用此通道，启动脚本切回 Cloudflare，并新增 check-public-preview.mjs 检查真实公网的登录跳转、Cookie 和语音状态。人物仍使用分块下载与重试；大文件速度和 iPhone 表现尚未完整验证。

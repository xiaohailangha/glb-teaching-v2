# 新窗口继续开发：人物表现与统一男童语音

用户于 2026-10-30 明确要求新窗口使用 **gpt-6-astra** 继续开发，旧窗口归档弃用。本文件是最新交接，优先于旧总交接中“等待新需求”“部署暂停”等历史段落。不要停在方案或重复询问确认，直接核对源码、修复、验证。

## 最新用户需求（最高优先级）

1. r4 动画更顺滑，但动作过少、人物呆板；上一版又摇晃过度。需要丰富且有意图的手势、眼神、表情、姿态变化，有清晰动作节拍、停顿和自然衔接，同时限制无目的大幅左右摇摆。不能只恢复旧循环或继续冻结更多姿态。
2. 语音不能不同单词在男女声之间切换。用户最新补充：成年男性不合适，改用小孩声音。结合此前要求，目标为**统一的同一个男童声音**，核查整词、音标、课程与本地回退所有来源；不能只换一个云端默认值。核实供应商音色能力并试听，不凭数字 ID 猜性别/年龄，也不把成年音简单升调冒充自然童声。
3. 偶发语音卡顿、操作不流畅，查请求/合成/缓存/预加载/播放/中断链路，找证据定位。保持快速连续点击下仅最后一次请求有效。
4. 点 apple 就直接读 apple，推广到所有单词；去掉该操作前后重复的套话旁白。点单词不应启动整套课程。独立音标点读保持只读所点音标；显式课程入口另行处理，不机械复制冗长旁白。
5. 先完成 Web 和手机复测，再打新引擎 Android 包。模型仍内置安装包。新窗口直接继续处理这些需求，当前窗口不再并行改实现。

## 工作目录、基线与线上

- 实际项目：`D:\AI语言训练\v2`。新窗口可能是 projectless，务必显式使用此目录，不在默认 C: 输出目录复制工程。
- 已核对基线：分支 `feat/flutter-scene`，HEAD `2dd4910a5157204856ea4138b0bf7cf9e3816d70`。交接开始时工作区干净；本交接文件是本轮唯一新增文档，尚未提交，不代表用户功能已完成。
- 私有仓库 `https://github.com/xiaohailangha/glb-teaching-v2`。公开 `mouth_teacher` 不改。大 GLB 已通过 LFS，不无谓重传。
- 当前新页面 `https://49.233.179.83/scene/`，r4；旧根页面保留。无需账号密码。
- 腾讯云主机 `49.233.179.83` / `lhins-52h0i09a` 是已授权测试部署目标。**ExtraVM 103.214.68.191 是现有代理 VPS，绝不操作。**
- 私人项目，不能纳入工作周报。`.secrets`、COS/腾讯云/SSH 凭据禁止打印或提交。
- 使用隐藏 IAB 验证，不占用用户工作浏览器；不操作用户未保存 Blender 场景，必要时独立后台 Blender。

## 先读这些资料

- `docs/PROJECT_HANDOFF_2026-10-30.md`：完整产品与历史；顶部新更新优先，下方旧“暂停部署/等待”已被后续授权和本次明确开发要求覆盖。
- `scene-preview/README.md`、`docs/flutter-scene/motion-fix-r4-2026-10-30.md`、`docs/flutter-scene/r4-verification.json`。
- 当前独立实现 `scene-preview/`，Web 是 flutter_scene WebGL2 后端，原生计划 Flutter GPU。不能用 Web FPS 证明原生性能。

## 动画与外观：应保留的修复，以及当前不足

- `scene-preview/lib/core/avatar/scene/intent_motion.dart`、`lesson_director.dart`、`secondary_motion.dart`、`scene_runtime.dart` 是优先入口。
- r4 普通教学按 `lessonPoseTime(phase)` 持有整段动画中的固定姿态，加少量事件动作；取消了周期性大幅摇摆，但最新反馈说明过于静态。需要改进动作编排和过渡，而非否定用户观感或仅提高插值速度。
- 保留主动/逆向四元数修复、每次渲染前恢复附加姿态、头眼头发同一头部变换、根部绑定等 r3 正确性修复。
- 原 GLB 裤子确实错误绑定到前臂/手指。`repairClothingBindings` + `assets/avatar/models/storm-clothing-bindings.{bin,json}` 修正，CPU 拉伸比约 290 降到 1.000044；不要回退。工具 `tools/generate-storm-clothing-bindings.mjs`、`tools/audit-storm-deformation.mjs`。
- 白边由不透明背景合成修复；角膜目前薄透明 PBR，避免 WebGL 折射黑片。
- **此前“原眼轴平行，所以原模型正常”判断已明确撤回。** 原 Blender 与导出 GLB 正面图都可见瞳孔偏鼻侧；眼轴平行不能证明眼眶内居中。r4 `neutral_gaze.dart` 使用 0.60 协同向外 Gaze 校准中性基形，眼皮/眼球/角膜一起变化，并保留运行时形变。不要回到独立旋转眼球、眼皮另走 Gaze 的错配。
- 原始 `.blend` / GLB 未改；vendor 的 rebindSkin、copyVertexData、64 morph 通道等补丁应保留。
- 用户原参考视频：`D:/newApp/weixin/xwechat_files/wxid_5286882869412_ca4e/temp/RWTemp/2026-10/9e20f478899dc29eb19741386f9343c8/e4e6171be39fb4e7c3b8f6400232d457.mp4`，先验证仍存在。参考观察有 `outputs/flutter-scene/user-reference-contact.png`、`reference-transition-r4.png`。重点是目的性、动作节拍和活力，不是随机多动。

## 语音与交互：已知入口，不等于根因

- `scene-preview/lib/core/avatar/scene/speech_client.dart` 当前请求 voice 403007，并可回退 `assets/avatar/audio/${clip.path}.wav`。`services/tencent-speech.mjs` 默认同 ID，允许 403006/403007/403008/403004；**这些音色的性别、年龄尚未在本轮核实**。
- 腾讯语音缓存键包含 version/text/voice/speed/language。检查改音色后云缓存、内置 wav、精选音标及其他播放器是否一致，不能漏掉旧资产。
- `scene-preview/lib/core/avatar/scene/speech_player_web.dart` / `_native.dart`，`scene-preview/lib/features/lesson/application/lesson_controller.dart`，`.../presentation/lesson_page.dart`；大词 onTap 当前 `_play` 路径需核实与整课调用关系。
- 保留 Safari 原始点击同步解锁音频、单 HTMLAudioElement、停止命令首个 await 前同步执行、await 后重查会话、失败解锁可重试、忽略旧 ended 事件、取消/过期请求不得更新声音口型或 UI。
- 不自动录音；麦克风由用户点跟读触发。不要把“我读好了”当真实评分。

## 构建、验证和交付

- 原 SDK `D:\flutter` 3.35.7 不动；独立 SDK `work/flutter-scene-sdk` 3.47.9，Dart 3.13.7。
- 在项目根运行：`tools/flutter-scene.ps1 analyze --no-pub`、`tools/flutter-scene.ps1 test --no-pub`、`tools/flutter-scene.ps1 build web --release --no-web-resources-cdn --no-pub --base-href=/scene/ --no-wasm-dry-run`。该 wrapper 使用临时 V:，**不可同时运行两个 wrapper**。
- r4 历史基线：26 Flutter 测试、analyze、Web release、6 组线上检查通过；桌面横竖屏已观察。用户最新反馈仍证明体验不足，不把旧通过记录当本次验收。
- 修改后重点验收：横竖屏人物自然动作但不晃；裤腿/眼角无回退；每个词/音标同男童音色；点 apple 立即只读 apple；快速换词无旧声音/重复套话/卡死；录音入口仍可用。实际 iPhone/Android 体验需与桌面证据区分。
- 现有 `tools/deploy-scene-preview.mjs`、`tools/test-scene-preview.mjs` 可维护已授权腾讯测试入口；修复后按现有流程验证，不动旧根入口和 ExtraVM。无需因纯代码/音频改动重传 89 个模型 COS 分块。
- `outputs/`、`work/`、源码模型、SDK/构建产物忽略提交。最后维护私有分支；已有 repo-only 密钥预提交检查，禁止绕过。

本次交接没有实施上述新需求，没有新声线试听、性能结论或新部署。接手后先核实源代码和最新运行状态，再落实并报告真实验证结果。

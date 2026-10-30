# glb模型能力：完整项目交接

交接日期：2026-10-30。用途：用户弃用过长的旧对话，后续在新对话继续整个项目开发，不只是部署。

**r4 后续修复：用户确认 r3 白边消失，仍反馈眼角、抬手扯裤腿、无目的摇摆与迟滞，并指出原模型正面图也有瞳孔偏鼻侧。源 GLB 裤子确有前臂/手指权重错误，已用校验绑定替换，CPU 三角形拉伸比由约 290 降至 1.000044；眼球/眼皮改用一致 Gaze，另做中性眼位向外校准。原轴平行不能证明眼眶内的瞳孔居中，此前正常判断已撤回。普通教学改按语义姿态持有、快速响应，不循环整段表演。26 项 Flutter 测试通过，详见 `docs/flutter-scene/motion-fix-r4-2026-10-30.md`。先完成 Web 手机观感复测，再 Android。**

**人物错位修复 r3：用户实测 r2 的苹果浏览器 50 FPS 以上，但反馈白边、眼球和头发漂移。已定位主动/逆向四元数旋转混用、平铺关节分别插值，以及额外绘制不恢复附加姿态的问题；新增真实 Storm 绑定回归，23 项 Flutter 测试通过。r3 以 GPU 内不透明渐变合成处理透明轮廓边缘；手机外观和 r3 帧率仍待原设备复测。以 `docs/flutter-scene/visual-fix-2026-10-30.md` 为本次证据，不将旧桌面截图当成手机通过。先 Web 再 Android。**

**Flutter Scene 后续验证：用户明确要求尝试新渲染器、先 Web 再 Android。独立实现位于 `scene-preview/`，线上入口 https://49.233.179.83/scene/ ，WebGL2 网页后端；原生计划使用 Flutter GPU。独立 SDK 3.47.9，不升级旧 SDK；模型继续内置原生包。已通过 21 项 Flutter 测试、341 个表演曲线采样对照、analyze、Web release，以及原 55 项 Node 回归。r2 帧率只计实际新绘制帧，剔除 GPU 复用上一帧的情况。详见 `scene-preview/README.md` 和 `docs/flutter-scene/web-verification.json`。旧根页面保留。新引擎 Android 构建、手机 FPS/发热及真实录音尚未验证，不能与旧 0.1.1 APK 的记录混淆。**

**Git 维护：用户选择新建私有仓库保存本项目，目标 `xiaohailangha/glb-teaching-v2`（已确认 Private），不改公开 `mouth_teacher`。main 为旧基线，feat/flutter-scene 为新验证实现；GLB 用 Git LFS，凭据/SDK/生成产物不入库。是否已同步以远端 refs 与 LFS 对象验证为准，不仅看本地 commit。**

**Android 最新状态：已为用户 S98Pro / Android 12 生成并发布 0.1.1+2 ARM64 release 测试包，下载 https://49.233.179.83/downloads/glb-teaching-0.1.1-arm64.apk 。模型内置，补上原生腾讯语音 HTTPS 转发及点击跟读后的 Android 麦克风权限；20 项 Flutter 测试、analyze、release 构建、签名和包内密钥排查通过。仍是 Flutter + WebView + Three.js，未迁移 flutter_scene；ADB 设备 offline，尚无安卓真机性能或录音验证。详情 docs/cloud-deployment/android-preview-2026-10-30.md。用户另报告 iPhone 约 34 FPS 并发热，仍需继续性能优化。**

**iPhone 后续修复：用户的 iPhone 13 Pro Max 在人物出现后整页循环重载；已上线 iOS 内存预算和移除启动自动刷新，55 个本地测试、15 组线上回归通过，桌面浏览器手机代码分支渲染通过。尚待原手机复测，不能宣称已在真机证实修好或把内存假设当成确诊。详见 docs/cloud-deployment/ios-reload-fix-2026-10-30.md。**

**最新访问更新：用户要求取消账号密码，已移除新腾讯云测试站的 HTTP Basic 验证。现在直接打开 https://49.233.179.83/，无需 family/admin 登录。已同步本地访问配置、Nginx 模板和回归脚本；服务端密钥仍受保护，ExtraVM 未操作。详情见 docs/cloud-deployment/README.md 顶部。下文测试账号描述仅为历史。**

**最新 COS 更新：用户已购买并明确授权配置 COS，现已接入线上测试站。实际付费包为大陆通用 10GB 标准存储一年。北京私有桶、短期只读签名、跨域配置、147 分块压缩、SHA256 完整性校验、按版本本地缓存、服务器回退均已完成。实测模型首次网络下载 5,293ms，重复打开 0 个模型网络请求；49 个本地测试、10 组线上回归、5 组 COS 检查通过。以 docs/cos-integration/README.md 为当前部署维护依据。入口仍为 https://49.233.179.83/，测试账号不变。**

**同日后续状态更新：用户买好新的腾讯云服务器并明确要求部署，现已部署至 https://49.233.179.83/ 。新腾讯云部署不再暂停；ExtraVM翻墙VPS仍不操作。详情和当前证据优先读 docs/cloud-deployment/README.md。下面的“未购买/部署暂停”保留为交接当时的历史状态，不得覆盖这条后续明确授权。**

## 0. 当前最高优先级指令

- **部署任务已明确暂停。** 不自动继续部署、连接 VPS、购买服务器、启动隧道或配置域名。用户后续明确恢复才继续。
- 本交接只转移上下文；接收后等待用户的新开发需求，不自行启动下一项功能。
- 全部项目和本项目输出放在 `D:\AI语言训练\v2`，不要因为新对话是 projectless 就在默认输出目录建立另一套项目。
- 私人项目，**不得纳入用户本周工作总结**。
- 用户在上班，不得擅自抢占或弹出私人浏览器。默认隐藏 IAB 测试。最近仅为腾讯云/ExtraVM 选购检查授权操作了已打开页面，不代表今后所有测试均可占用 Chrome。
- **现有 VPS 正运行用户翻墙服务：不重装、不重建、不破坏或停止现有服务，不贸然重启，不改其端口、网络、路由、防火墙、证书。** 部署恢复后也必须先只读检查并安全共存。
- 不操作用户已打开且未保存的 Blender 场景；导出用独立后台 Blender。
- 区分已实现、历史测试、设计、未验证项；不要承诺官网视频100%复原、手机120FPS或精准舌位教学已经完成。

## 1. 产品方向与核心体验

这是 Flutter 英语发音/词汇/听说教学 App。人物在左侧，右侧展示单词、音标、中文含义或句子。用户希望角色像参考视频中活生生的人，自然教学，不是呆板朗读、固定两按钮演示或几个表情循环切换。

最初从 Snow 验证，用户后来下载 Storm，已明确只用 **Storm v1.1**。页面名称是 **glb模型能力**，不要恢复“小小发音课”。工程内部旧名 snow_speaks、snow-avatar-tools 不表示默认人物仍是 Snow。

用户成人零基础目标：认识很多单词，能简单对话、能听懂别人。学习时间每天不同，可能10分钟、半小时或1小时，随时停止、随时回来，打开就能学，不用固定日程约束兴趣。产品兼顾儿童、成人零基础、有基础纠音三条路线。

## 2. 已确认的视觉和人物要求

- 灰色整屏渐变、左侧人物近景、右侧大白字，简洁，不做明显分屏或分割线。人物全幅透明画布，手臂可延伸到右侧文字后面，文字浮在前景，超出页面边缘才裁切。
- 构图是肩膀往下一些、比参考再低一点，让手势能进入画面；不要回到宽泛完整上半身远景。
- 不固定身体斜角：根据情境左右侧身、换向、转身、手势、多角度自然衔接。转圈可出现在适合的表演场景，不应每个单词周期性转圈。
- 用户明确反对“示范发音就压制大动作”，正常身体表达应保留，靠合理衔接保持鲜活。
- 眼球不能像贴图或斗鸡眼，要有深度、角膜高光、共同注视目标；眼睛先行、头跟随、肩膀滞后，情绪细腻连续。
- 等待操作时仍有呼吸、眨眼、眼神和细微姿态，避免读完彻底静止。但不能自说自话不断催促用户。
- 头发摇头/转身时有更明显惯性，根部固定、发梢柔软、阻尼衰减、限幅；不是随机摆动。现有方案无完整碰撞/逐根毛发模拟，不能宣称精确物理。
- 情绪库有开心、伤心、沮丧、害怕、生气、惊讶、好奇、疑惑、害羞、自豪、厌恶、释然12段；重点是融入日常教学，不只是演示按钮。

参考素材：
- 官方人物：https://studio.blender.org/characters/storm/v1/
- 用户视频路径（可能是临时文件，访问前验证存在）：`D:/newApp/weixin/xwechat_files/wxid_5286882869412_ca4e/temp/RWTemp/2026-10/9e20f478899dc29eb19741386f9343c8/e4e6171be39fb4e7c3b8f6400232d457.mp4`
- 用户多次截图位于 `C:/Users/dyw/AppData/Local/Temp/`；优先看项目内 `docs/layout-reference.png`、Storm预览和实录，不假定临时图片还在。
- 模型源文件以项目 `source-models/storm/storm_v1.1.blend` 为准；文档记录用户原文件 `E:\教学app素材\storm_v1.1.blend`，旧消息提过同名前缀目录。

## 3. 单词、音标与交互决策

- 去掉 LISTEN & REPEAT，用音标和中文释义。
- 大英文词、中文含义、音标练习块都可独立点读；点某个音标只播该块，不自动拆完整词逐个播放。
- 音标颜色帮助零基础辨认组合；不加“从左往右点着听”等教学外提示。
- apple 的练习块是 `æ`、`p`、`əl`；用户反对把 ə 和 l 拆成四块。尾部 `əl` 连续播放一个音频/时间轴，不能误称3个音节。复合音标 `uː`、`oʊ` 等也不能按字符随意拆。
- 新点击立即中断旧声音/口型/过期会话；不能重叠播放、接收旧评分后更新新词。
- 交互讨论最终保留必要按钮控制“下一个、再说一遍、慢一点”等；**取消以语音命令控制课程为默认方案**，降低开发复杂度。按钮录音用来学习，不等于恢复语音命令。
- 曾讨论点人物任意位置暂停，已被用户撤回；不要实现该旧提案。
- 用户希望点句子中的单词，人物立即解释该词，然后自然衔接回原课程，减少来回按钮。返回细节仍需结合需求确认/设计，不可说完整流程已实现。
- 句子中**系统正式教过的词变蓝**，不等同掌握。点开陌生词临时解释，无论是否讲完都**不计入正式教过**，不能自动变蓝。正式教学记录、掌握证据、临时查词必须分开。

## 4. 课程方向：设计与实现边界

- 初次使用选择儿童/成人零基础/有基础纠音，儿童再按年龄适配。
- 成人零基础要兼顾发音基础、词汇积累、听懂和简单对话；用户询问应从音标与背单词开始，后续不是只做孤立音标训练。
- 用户倾向共用课件库，以年龄、目标、基础、学习证据等条件组合适合课程，而不是维护三套完全重复内容。
- 课程切成可随时停续的小单元，时间不固定；不要强制每天10/30/60分钟打卡计划。
- 通过自然互动、听辨、回忆、跟读获得学习证据，不要让用户感觉不停考试。点“我读好了”只说明尝试过，不能当作评分或掌握。
- 身体语言、表情和情绪要跟教学意图、学习者回答、帮助/反馈状态对应，不能随机情绪或机械循环。
- 已有设计文件：`docs/curriculum/英语教学三条路线课程大纲.html`、`curriculum-v1.json`、`人物教学表演适配方案.html`、`course-acting-plan.json`，archive内有历史版本。用户曾明确要求先讨论，不能把所有讨论直接当作课程大纲改动授权。
- 文档记载38个蓝图、152个微课主题的表演规划；**不是152节已制作课件**。
- 当前运行：原有10单词、共用教学导演层、apple完整互动样板。演示库→课程表演·apple→成人零基础/三个儿童年龄版本。
- apple样板包括讲解、整词、单音、听辨、帮助、回忆、尝试反馈；儿童以水果图片辅助。年龄版本只是该目标的讲解/表演差异，不是儿童完整课程。
- 注册登录、持久学习档案、课程管理后台和正式自适应排课尚未完成；未来动作如跑跳、触鼻、地图指路等也未全部完成。
- 通用聊天大模型并未确定为必需依赖；不要把腾讯语音产品的“大模型”名称误解为已经接了课程生成聊天LLM。

## 5. 技术架构与关键入口（本次已读文档并核实文件存在）

- Flutter界面/状态；Web iframe、Android/iOS WebView共用本地Three.js场景；通过JSON桥接指令/事件。原生loopback服务读取包内资源。
- `lib/main.dart`、`lib/app.dart`；`lib/core/avatar/`各平台适配。
- `lib/features/lesson/domain/lesson_word.dart`、`phonetic_token.dart`；application/lesson_controller.dart；presentation/lesson_page.dart。
- `lib/features/settings/application/app_settings.dart`、presentation/settings_panel.dart。
- `assets/avatar/avatar.js`主渲染；motion.js口型；lesson-director.js日常教学；course-director.js课程；acting-director.js连续身体表演；secondary-motion.js头发；eye-materials.js眼睛；render-quality.js画质；performance.js诊断。
- `assets/avatar/cloud-speech.js`、recording.js、microphone-worklet.js；`services/tencent-speech.mjs`、speech-http.mjs；根目录server.mjs。
- 模型 `assets/avatar/models/storm-performance.glb`，约153MB、128关节、52变形通道；文档记载425,144三角形、42头发关节。元数据storm-rig.json。
- `tools/export_storm.py`、storm_materials.py、audit_storm_fidelity.py、validate_avatar.py。材质/法线/粗糙度烘焙与几何细分均重要；不要为了减包随意丢掉用户要求的保真细节。
- `work/storm/storm-runtime.blend`是转换场景；Snow文件是历史备份，不再作为打包主角。
- package.json当前Three.js 0.180.0；pubspec中webview_flutter4.13.1、shared_preferences等。版本是已读源码快照，不代表最新市场版本。
- README有旧段落与后加说明；冲突时以最新用户决策、当前源码及对应日期报告为准，不能引用旧“无麦克风”段落否定新接入。

## 6. 腾讯云语音：最终决定与边界

- 用户评估过讯飞，因家庭使用资源包/费用原因最终优先腾讯。不要重新切回讯飞或要求开通旧服务。
- 三项已开通，文档记载2026-10-29真实调用通过：教学TTS、ASR、SOE。
- TTS：超自然大模型2.0，流式文本stream_wsv2，默认YunLeo403007。
- ASR：实时V2，16k_zh_en_2.0，用于回忆回答转写，不把答案配置成热词来“作弊”。
- SOE：新版soe/api，英文词句跟读，苛刻指数2尚未儿童校准；评测不是掌握证明，不据此擅自自动推进。
- 单独 `/æ/` 等音素不要求跟读、不做评测；孤立音素/组合音标保留已适配的本地音频。
- TTS所选音色无可用时间戳，当前合成后用同一音频SOE PhoneInfos取时序，再映射viseme，音频currentTime驱动。不能把新声音配旧时间轴。
- 首次生成产生TTS和SOE对齐费用；按文本/音色/速度/语言/版本缓存，重复播放复用。固定历史10秒表演保留其音频和时间关系。
- 用户最终放弃子账号方案，授权主账号API密钥方式；密钥只在服务端 `.secrets/tencent.json` 或TENCENT_APP_ID/SECRET_ID/SECRET_KEY环境变量。**不输出密钥、不打包进前端、不上传整项目含.secrets目录。**
- 点击跟读才请求麦克风，15秒自动结束，可“说完了”提前结束；切词/停止必须关闭麦克风并丢弃过期响应。不要录办公室声音做测试。
- 真实服务测试工具tools/test-tencent.mjs只用合成素材但会产生少量费用；不要无意义重复调用。
- `docs/tencent-integration.md`与docs/tencent-integration/latest-report.json是证据入口。接口通过≠真人/儿童/嘈杂环境准确率已验证；精细舌位还需专业校准。

## 7. 性能、平台、验证现状

- 用户从60FPS推进到高刷适配：高最高120/中最高60/低最高30，自动适应开关、默认高+自适应；设置持久化，统一设置入口以后扩展。
- 同一人物/动作保留；优先调DPR/阴影，慢帧再降节拍，稳定余量后恢复。采样浏览器回调得到可用调度频率，不冒称物理屏幕刷新率。
- 动画按经过时间、口型按音频时间，不能随帧率加速；90Hz下中档可整除到45FPS。
- iOS CADisableMinimumFrameDurationOnPhone=true；Android按支持情况提交刷新率偏好，不能覆盖系统温控/省电决定。WebView120并未真机证实。
- 原生App左右横屏；Android sensorLandscape，iOS方向限制；Web manifest横屏+竖屏旋转提示，Safari不能承诺强制锁方向。
- 用户无Mac，目前Safari试验。iOS构建仍需Mac/Xcode或云Mac与签名，过去用户粘贴的“官方黑科技/一次借Mac永远不用/免费额度够”等不是已验证方案。
- docs/storm-integration.md最新v4历史报告：桌面GTX1050Ti，1280×720，30秒60FPS、P95 16.8ms、GPU P95 11.89ms、valid=true；不是手机性能保证。
- 该文档记载40 Node、17 Flutter测试、analyze/Web/Android debug通过；后续分块下载加入后旧对话记载43 Node和Web构建通过。**本交接没有重新跑测试**，引用时带版本/日期，改代码后重测相关项。
- `docs/performance-reports/`、`docs/storm-continuous-acting.mp4`、`storm-continuous-teaching.mp4`、`storm-continuous-preview.jpg`、render-settings-preview.jpg可用于复核。Snow历史结果不能充当Storm验收。

## 8. 本地运行、资源更新与网络方案

- npm start / 启动预览.cmd，通常127.0.0.1:5296；普通页/，诊断?perf=1，演示?demo=1，独立语音测试/avatar-dev/speech-test.html。
- Flutter在D:\flutter，tools/flutter.ps1临时映射V:避免中文路径shader问题；**不能并行运行两个包装器**。
- 常用：npm test；npm run check；tools/flutter.ps1 analyze --no-pub；test --no-pub；build web --release --no-web-resources-cdn --no-pub。只按本次改动验证，交接本身不用跑全套。
- 用户决定：正式原生包内置Storm/基础动作/渲染能力，避免首次下载。**课程内容不打进安装包**，服务端更新；课程编排、词句/顺序与资源版本动态获取、缓存。新能力仍可能需要发版。
- 文件存储用于课程音频/图片/时间轴/额外资源。家庭初期可先放服务器硬盘，COS不是立即必购；账号/学习进度是数据库，不是对象存储。Web与原生资源分发不同，Web仍需下载模型。
- 先前临时localhost.run域名失效返回no tunnel，SSH存活也不代表域名有效；Cloudflare Quick Tunnel也不保证持久在线，不能给用户旧token链接。
- tools/start-public-preview.ps1 / stop-public-preview.ps1 / public-preview.mjs / check-public-preview.mjs / test-public-preview.mjs和根目录手机外网cmd为历史方案；5297网关有12小时访问凭据，不可原样当永久服务。
- model-download.js支持HEAD广告的1MiB分块、3并发/重试、120秒请求超时；无广告时回退单fetch，支持需与服务器一致。不要无证据强行加入跨域或部署限制。
- 临时内网5298入口HTTP不能覆盖手机麦克风测试；真实iPhone模型完整加载、录音/性能仍待验证。

## 9. 云服务器及暂停状态

- 用户先评估腾讯云，明确不买香港、选大陆。曾在已登录购买页选好北京2核4GB、60GBSSD、5Mbps、500GB/月、Ubuntu24.04LTS，1年1台，报价312元，自动续费关，名称glb-teaching-web。**没有勾选协议、没有提交订单付款**；报价仅2026-10-29页面快照。
- 随后用户提供已有ExtraVM，想暂用它省下新服务器购买，授权开始后又提醒保护翻墙，最终明确**暂停部署**。这不是永久取消腾讯或永久决定东京正式架构。
- ExtraVM：https://vm.extravm.com/server/7df73aac-f8d0-4931-813e-726da0d0d542
- 当时只读面板：xiaohailang，Tokyo Japan，Ubuntu24.04.4LTS，1核AMD EPYC4464P，约961MB内存，15GB主盘，公网103.214.68.191，出站上限500Mbps，周期1000GB剩约791GB。内存18%、CPU1.4%；磁盘实际余量与现有服务未知。桌面看到500Mbps不是大陆线路实测。
- 旧对话未对VPS执行重启/重装/修改。新对话创建后被暂停打断，其实际只读准备操作以新对话自身记录为准，不能笼统声称从未运行过本地读取命令。
- 域名购买状态、SSH连接凭据、80/443占用均未核实。未来恢复也不得猜密码、重置密码/证书或覆盖代理配置。需HTTPS+访问控制+后端保密，先只读盘点，再独立部署且可回滚。
- 大陆服务器绑定域名Web需备案；香港/东京网站托管情境与大陆不同，不要把“不需该网站备案”泛化成所有App业务免合规。

## 10. 新对话应如何继续

1. 先确认收到完整项目交接、部署仍暂停，然后等用户下一条开发需求。
2. 根据具体需求选读docs与源码，不重新要求用户重复整个历史，不重新从Snow做起。
3. 不将课程讨论全量视作实现授权；不把文档规划数量、老测试和合成语音评分当成实际完成。
4. 保留用户最在意的自然人物表现、极简UI、灵活学习、科学诚实反馈、私人项目隔离与现有VPS完整性。

本交接来源：旧对话用户原话/已见工具证据；本次读取README、docs/integrated-teaching.md、docs/tencent-integration.md、docs/storm-integration.md、package.json、pubspec.yaml、settings源码并列出目录。未重新做性能、远程、语音或构建验证，未读取/抄录任何密钥。

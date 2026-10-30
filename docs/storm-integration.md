# Storm v1.1 接入记录

2026-10-29：按用户要求替换默认人物，Snow 不再作为运行模型。

## 源文件与转换

- 用户原文件：`E:\教学app素材\storm_v1.1.blend`，未改动。
- 项目源文件：`source-models/storm/storm_v1.1.blend`。
- 转换脚本：`tools/export_storm.py`；独立后台 Blender 5.2，不操作用户已打开的 Blender 场景。
- 可编辑转换场景：`work/storm/storm-runtime.blend`。
- 运行模型：`assets/avatar/models/storm-performance.glb`，153,334,024 字节；128 关节、52 个面部/姿态变形通道。
- 动作：10 秒教学身体动画，72 秒十二情绪动画。按 Storm 自身 FK、面部控制和约束重新烘焙，不把 Snow 的网格直接套上去。
- 贴图：原材质基础颜色、粗糙度和切线法线烘焙；头部及头发使用 2048 像素纹理；眼球和角膜为分离的原模型几何，保留瞳孔贴图、注视变形和角膜高光。
- 眨眼：从原模型控制器 `PRP-Eye_blink` 的实际驱动公式提取；情绪使用独立闭眼修正。厌恶姿态原本已闭眼，不额外叠加闭眼变形。

## 2026-10-29 保真与动作修正

- 查明旧版的具体损失：只有颜色贴图、缺少发丝法线；统一材质粗糙度；绑定驱动把导出细分重新设置为 0；独立头发骨骼被折叠到头部。
- 当前头部为 75,655 顶点、头发主体为 60,090 顶点，头部及头发恢复原文件渲染用二级细分；不能仅设置 levels 而保留覆盖它的驱动器。
- 重新烘焙原着色器的颜色、粗糙度、法线。颜色用发光通道读取原始 Base Color，避免将次表面散射照明烘焙进底色。保留 UV Alignment 到全部烘焙结束。
- 眼球与角膜绑定到两根独立眼骨，按同一个远处目标整体转动，眼球不再使用线性注视变形；GLB 的眼睛前轴是 +Z。仍需结合实际画面持续校准眼神表演。
- 恢复 42 个头发关节及原蒙皮，运行时按头部角速度驱动有阻尼的弹性偏移，包含点头、摇头和歪头。根部固定、分段限幅、停止后衰减；不是布料或逐根毛发物理，也未做完整头皮碰撞求解。
- 添加柔和阴影，降低原来过亮的环境光；Blender 的次表面散射和实时材质仍有差异，不能声明像素级 100% 复原。
- 原文件只有单帧 Face/Hand 姿势资产，没有用户提供视频中的 18 秒完整表演；当前教学关键帧与情绪编排是本项目的独立实现，不能把模型导入当作动画影片自动复现。
- 新版独立预览实测：1265×712、DPR 1、GTX 1050 Ti，版本 storm-v2-fidelity，425,144 三角形；连续 30 秒身体/面部/头发表演 60 FPS、P95 16.8 ms、慢帧 0、GPU P95 10.11 ms、valid=true。头发局部峰值偏移约 0.0476 弧度。报告 performance-reports/2026-10-29T07-35-04-975Z.json。
- 最终正式 Flutter Web 复测：1280×720，连续表演 30 秒，60 FPS、P95 16.8 ms、慢帧 0、GPU P95 10.66 ms、valid=true。报告 performance-reports/2026-10-29T07-44-49-945Z.json。
- 新的算法测试检查共同注视点、无累计旋转、发梢停止衰减、15/30/60/120 FPS 下的稳定性，以及高细分是否被驱动器意外复位。

## 声音与演示

普通教学调用腾讯超自然大模型 2.0，SOE 新版取得同一声音的音素时间，按音频 currentTime 驱动嘴型。身体和表情通过已有教学阶段编排混合，等待时保留呼吸、眼神和眨眼。尚不是根据任意文本生成全新身体动作。

`docs/storm-fidelity-teaching.mp4` 为本次修正后的本机实际 GLB 运行录制，约 12 秒，腾讯 YunLeo 403007 配音，65 个音素区间。仅录制应用渲染画布与合成音频，不录制桌面、私人浏览器或麦克风。视频右侧文字由录制模块绘制；正式页面由 Flutter 绘制，见 `docs/storm-fidelity-preview.jpg`。

本次完整情绪录制为 `performance-recordings/2026-10-29T07-43-14-844Z.webm`；从中选取开心、害怕、好奇、自豪四段生成 `docs/storm-fidelity-emotions.mp4`。旧的 storm-tencent-demo.mp4 保留为修正前记录。

## 验证

- Node：32 项通过，含 Storm 眼球/角膜结构、情绪目标、128 关节归一化蒙皮、口型连续性和腾讯签名/音频边界。
- Flutter：analyze 无问题，15 项测试通过，Web release 构建成功。
- 三种真实服务：TTS、ASR V2、SOE 新版均成功；合成音频测试结果见 `tencent-integration/latest-report.json`。没有录制办公室声音，真人麦克风录入和不同口音仍待使用者测试。
- 第一版历史结果（本次不能代用）：独立预览 1265×540、DPR 1、GTX 1050 Ti、版本 `storm-v1-tencent-2`，30 秒云端口型循环 60 FPS，P95 16.8 ms、慢帧（>25 ms）0、valid=true。报告 `performance-reports/2026-10-29T07-03-11-737Z.json`。
- 第一版历史结果（本次不能代用）：正式 Flutter Web 1280×720、相同设备与版本，30 秒云端口型循环 60 FPS，P95 16.8 ms、慢帧 0、valid=true；CPU P95 2.2 ms，GPU P95 6.79 ms。报告 `performance-reports/2026-10-29T07-05-48-764Z.json`。
- 手机真机未测试；桌面结果不能保证所有设备 60 FPS。

Blender 的离线渲染材质、毛发细节和光照与实时 GLB 有差异，当前不是官网宣传片画质的逐像素复现。嘴型仍需人工逐音素校准，尤其精细舌位不能用本次接口通畅测试代替教学准确性验收。

## 署名

Storm Rig (CC) Blender Foundation | studio.blender.org

来源：https://studio.blender.org/characters/storm/v1/  
许可：https://creativecommons.org/licenses/by/4.0/  
项目修改：材质烘焙、实时网格与骨骼适配、面部姿态及身体动作烘焙、GLB 导出和数据压缩。应用信息面板已更新署名。


## 2026-10-29 连续表演、构图和转身

版本 `storm-v3-continuous-acting`。

- 近景镜头下移到胸口上方，保留抬手动作的空间；正面、左右侧身连续变化，不固定在一个斜角。
- `acting-director.js` 把注意力变化、眼睛先行、头部跟随、肩膀滞后、左右手势、眉眼与笑意分开编排后连续混合。教学阶段会调整身体朝向，倾听时回到学习者；嘴型仍由同一音频时间驱动。
- 24 秒演示包含左右换向、手势和一圈完整转身。转圈是演示的庆祝段落，不会在每个单词朗读时循环插入。
- 根节点角度使用最短角差连续跟踪，转完一圈或中断后不会反向倒转一整圈。头、两眼和头发共享旋转中心；手和前臂成组旋转，避免只有手腕漂移。
- 角膜保留环境反射，并增加轻量曲面高光近似；高光位置随相机/光源变化，使用深度遮挡，眨眼时收起。此实现不是离线路径追踪的完整光学模拟。
- 头发从头骨的世界旋转计算速度，因此整个人转身也会驱动惯性。使用四元数差避开 180 度角度跳变；发梢比根部柔软，弹簧带阻尼与限幅，停止后衰减。发梢局部上限 0.13–0.15 弧度，仍没有完整碰撞求解，不能宣称全部运动都符合精确物理。
- 自动测试共 36 项通过，包含视线领先、姿态循环连续、骨骼恢复无累积、口型闭合、整身转圈驱动头发、30/60/120 FPS 稳定性、停转衰减。Flutter Web release 构建通过。
- 实录仅取本项目画布和合成声音；没有录制用户桌面、私人浏览器或麦克风。尚未验证真机移动端性能，也没有宣称完全复现参考视频。

- 最终正式 Flutter Web 连续转身实测：1280×720、DPR 1、GTX 1050 Ti，30,015.6 ms / 1,801 帧，60 FPS、P95 16.9 ms、CPU P95 3.5 ms、GPU P95 12.05 ms、超过 25 ms 慢帧 0、valid=true。报告：`performance-reports/2026-10-29T08-17-05-897Z.json`。本轮转身发梢局部峰值 0.13 弧度，旧版实测约 0.0476。
- 最终多角度实录：`storm-continuous-acting.mp4`（24 秒，无声，包含完整一圈转身）；教学实录：`storm-continuous-teaching.mp4`（约 12 秒，腾讯合成语音、65 个音素时间区间）；正式页面截图：`storm-continuous-preview.jpg`。


## 2026-10-29 设置与自适应渲染

- 正式页面右上角增加统一设置入口，独立 `features/settings` 模块保存偏好，可扩展后续声音/字幕等设置；当前不展示未实现的占位开关。
- 三档：高档最高 120 FPS、像素倍率上限 1.5、阴影 1024；中档最高 60 FPS、倍率上限 1.25、阴影 768；低档最高 30 FPS、倍率上限 1、阴影 512。倍率还受实际设备 DPR 限制。三档保留同一模型、表情、口型和动作，没有偷偷替换低精度人物。
- 默认高档与自动适应开启。选择立即通过角色命令桥接生效，以 shared_preferences 保存；刷新/重启后恢复。实测网页低档约 30 FPS、刷新后仍为低档、切回高档恢复 60 FPS。
- 在模型加载时采样 48 次浏览器帧回调，区分实际可用的 60/90/120 等调度频率，不把它冒称为物理屏幕标称刷新率。低于频率上限的档位采用整除节拍，例如 90 Hz 调度下中档采用 45 FPS，避免 90 与 60 硬拼导致帧间隔交替。
- 持续慢帧先降低像素倍率；到下限仍跟不上时再降到可用节拍的下一档。恢复必须有至少约 12 秒稳定余量，先恢复帧率再恢复精度。关闭自动适应后保留用户指定档位；真实帧率统计仍如实显示。
- 动画使用经过的时间、口型使用音频时间，切换 30/60/90/120 不改变动作速度。新增按目标帧预算统计的慢帧数，避免把低档正常的 33.3 ms 全部误判成异常；旧的 over25ms 仅保留为固定阈值统计。
- iOS Runner/Info.plist 原本已经有 CADisableMinimumFrameDurationOnPhone=true，本次核实后保留。Android 使用设备支持且分辨率一致的刷新率，按档位提交 preferredRefreshRate 偏好，最高 120 Hz；不强行设置显示模式 ID，不覆盖系统省电、温控最终决定。
- 这是 Flutter + WebView 的双层呈现。平台偏好不等于 WebView 实际达到 120 FPS，90/120 真机能力仍待对应设备测试；模拟时序测试只验证调度算法。
- 验证：40 项 Node 测试、17 项 Flutter 测试通过；Flutter analyze 无问题；Web release 与 Android debug 构建成功。iOS 无 Mac/iPhone 构建与真机证据。
- 参考：Apple ProMotion https://developer.apple.com/documentation/quartzcore/optimizing-iphone-and-ipad-apps-to-support-promotion-displays ；Android 帧率偏好 https://developer.android.com/media/optimize/performance/frame-rate ；浏览器帧回调 https://developer.mozilla.org/en-US/docs/Web/API/Window/requestAnimationFrame 。
- 最终 v4 正式页面复测（高档、自动适应开启）：1280×720、DPR 1、GTX 1050 Ti，30,015.6 ms / 1,801 帧，60 FPS、P95 16.8 ms、CPU P95 3 ms、GPU P95 11.89 ms、overBudgetFrames=0、over25ms=0、valid=true。报告：performance-reports/2026-10-29T08-43-43-197Z.json。设置面板实图：render-settings-preview.jpg。

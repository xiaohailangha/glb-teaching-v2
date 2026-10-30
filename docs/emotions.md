# Snow 情绪表演

项目：D:\AI语言训练\v2，Flutter 页面名称为 glb模型能力。

进入本地预览 http://localhost:5296/?demo=1 ，点击「情绪演示」。下拉选择单段，点击「重播」再次播放，「全部连播」从开心开始播放 72 秒；「停止」退出当前表演。「10 秒教学表演」返回教学内容。方向键在情绪模式下切换情绪，空格播放/停止。

## 表演目录

每段 6 秒，包括进入情绪、主要反应、余韵和回落。无声，便于单独观察脸部与身体的表达。

| 情绪 | 肢体与表情 |
| --- | --- |
| 开心 | 提起脸颊、笑容、打开双臂与轻微身体起伏 |
| 伤心 | 内眉抬起、下垂嘴角、低头收肩和垂下的视线 |
| 沮丧 | 眉头压紧、抿嘴、摇头与摊手 |
| 害怕 | 眼睛睁大、紧张嘴型、后缩与双手防护 |
| 生气 | 压低眉毛、绷紧嘴角、前倾和收紧手指 |
| 惊讶 | 眉眼快速打开、圆嘴、突然抬起双手 |
| 好奇 | 挑眉、靠近、偏头与单手探询 |
| 疑惑 | 不对称眉毛、左右观察、歪头摊手 |
| 害羞 | 含蓄微笑、移开视线、收肩与双手内收 |
| 自豪 | 抬下巴、挺胸、舒展手臂与克制微笑 |
| 厌恶 | 眯眼、收紧上唇、转开身体和拒绝手势 |
| 释然 | 呼气般的胸部回落、肩膀放松、笑容恢复 |

## 实现与重建

- 面部使用 Snow 原始控制绑定烘焙，每种情绪包含对应的眼睑闭合差值，避免睁眼表情与中性眨眼简单叠加。
- 72 个关节，在原绑定上编排并以 20 Hz 采样成 `Emotion_Reel`，显示时由 Three.js 连续插值。采样率不是显示帧率。
- `Teaching_Apple_10s` 从上一版已验证 GLB 中复制动画数据，按唯一节点名称重映射；不复制第二份几何与纹理。
- 情绪切换具有 0.35 秒身体/表情过渡。教学继续按音频时间播放；无声情绪按单调时间同步面部与身体。
- 面部、角膜、眼球保留变形法线和正式材质。只使用本地资源。

独立后台 Blender 命令：

```powershell
& 'D:\newApp\blender\blender.exe' -b work/performance-render-eyes.blend -t 4 --python tools/build_emotions.py
```

输入教学基线：`work/emotions-baseline/snow-performance.glb`。输出模型：`assets/avatar/models/snow-performance.glb`，编辑场景：`work/performance-emotions.blend`。不要把已带情绪的输出覆盖输入基线；完整从源重建的步骤先执行 `docs/teaching-performance.md`，再执行本步骤。

表演配置与播放：`assets/avatar/emotions.js`；原绑定编排：`tools/build_emotions.py`；Flutter 目录：`lib/features/lesson/domain/emotion.dart`。

## 验证

静态分析与 10 项 Flutter 测试通过，包括情绪切换的会话隔离以及四种尺寸下的情绪界面。15 项 Node 测试通过，覆盖全部情绪目标、独立眨眼差值、72 秒骨骼片段、10 秒教学片段保留、归一化皮肤权重及表情连续性。release Web 构建通过。

最终资产为 13,188,580 字节，59,214 个三角面，72 个关节。视觉检查覆盖完整 12 段表演；特别检查了大幅睁眼表情的眨眼闭合，并提高好奇、疑惑表情的上眼睑，避免显得困倦。Flutter 实页确认了下拉切换、重播、连播中的标题同步、结束状态与切回教学表演。

最终性能报告：`performance-reports/2026-10-28T07-55-34-321Z.json`，版本 `teaching-v7-emotions`。完整 Flutter 页面，1280×720，NVIDIA GTX 1050 Ti / ANGLE D3D11，隐藏的 Codex 内置浏览器（内部文档状态 visible）。没有操作用户的 Chrome。

| 指标 | 结果 |
| --- | --- |
| 测量时长 | 72,014.2 ms |
| 实际帧数 | 4,321 |
| 平均帧率 | 60 FPS |
| 帧间隔 P95 | 16.8 ms |
| 超过 25 ms 的帧 | 0 |
| CPU P95 | 1.6 ms |
| GPU 采样 P95 | 3.85 ms |
| valid | true |

测试先预热 2 秒，随后记录 72 秒，覆盖整组情绪（开头两秒为预热，末尾含约两秒待机）。录制与性能测量分开进行。以上是此电脑的运行结果，Android/iOS 真机未测试。

最终演示：`snow-emotions-72s.mp4`；实际 Flutter 页面：`snow-emotions-page.png`。视频来自应用自己的 WebGL 画布，叠加情绪中英文标签，没有录制桌面、麦克风或其他窗口。作为第一批手工编排的情绪样片，它没有实现任意语音内容的自动情绪理解。

Snow Rig (CC) Blender Foundation | studio.blender.org
来源：https://studio.blender.org/characters/snow/v4/ ，许可 CC BY 4.0。
本项目新增原创建模控制编排、表情混合与 GLB 转换；没有上传到外部服务。

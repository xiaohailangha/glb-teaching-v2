# Snow 10 秒教学表演

本版页面名称：glb模型能力。项目位置：D:\AI语言训练\v2。

## 观看

- `http://localhost:5296/?demo=1`，点击右下角「10 秒教学表演」。
- 最新眼球修正版视频：`snow-render-eyes-10s.mp4`，10 秒，1280×720，包含语音。`snow-expression-10s.mp4` 为前一版。
- 页面实拍：`snow-render-eyes-page.png`。

视频采集的是实际 WebGL 动画和应用生成的音频；灰色背景、单词在录制画布中合成，未采集桌面、其他浏览器窗口或麦克风。Flutter 页面本身已单独验证。

## 表演与构图

0–1.8 秒：看向观众、招呼和挥手。
1.8–3.8 秒：眼神先移向单词，头与身体随后转动，手势引出 APPLE。
4.0–5.8 秒：示范 Apple，保持眉眼变化、点头和手势。
6.0–7.8 秒：Your turn，伸手邀请。
7.8–10 秒：回到观众，轻微前倾、侧头倾听，表情自然回落。

人物处在左侧，但透明 3D 画布覆盖整个页面，不在左右区域的边界裁切。Flutter 单词和按钮在人物上层，手臂可以经过文字后方。只按页面边缘截断画面。

## 实现

- 72 个运行时关节，59,214 个三角面；当前眼球修正版 GLB 为 8,908,868 字节。
- `Teaching_Apple_10s`：在 Blender 原始 Snow 控制绑定上编排、以 30 Hz 采样并导出；WebGL 连续插值显示，骨骼采样频率与显示帧率是不同指标。
- 面部独立控制：口型、双向水平/垂直眼神、左右眉毛和嘴角、眨眼、放松/好奇。
- 修正了眼神控制的导出轴、手臂方向、骨骼绑定矩阵与衣领穿插；手指采用原模型 Relaxed 手势。
- 身体与口型以同一条 10 秒音轨为时间基准。重复播放、停止和切词使用会话取消，不让旧音频事件污染新状态。
- 保留前一版模型 `assets/avatar/models/snow.glb`。

## 性能与检查

当前眼球修正版最终实测：`performance-reports/2026-10-28T07-17-11-361Z.json`，版本 `teaching-v6-render-eyes`。

| 指标 | 结果 |
| --- | --- |
| 完整 Flutter 视口 / 3D 画布 | 1280×720 / 1280×720 |
| 实际 rAF 测量时长 | 30,015.7 ms |
| 平均帧率 | 60 FPS |
| 帧间隔 P95 | 16.8 ms |
| 超过 25 ms 的帧 | 0 |
| JS CPU P95 | 1.6 ms |
| GPU 采样 P95 | 3.82 ms |
| 测试有效性 | valid: true |
| 渲染器 | NVIDIA GTX 1050 Ti / ANGLE D3D11 |

测试在隐藏的 Codex 内置浏览器中进行，未操作或弹出用户的 Chrome。该隐藏预览内部的文档可见性为 visible，实际收到了 60 Hz rAF；没有禁用后台节流或伪造帧率。结果仅代表此电脑和视口，不代表 Android/iOS 真机性能。

- `flutter analyze --no-pub`：通过。
- Flutter 测试：9 项通过，包括会话取消、表演入口、四种页面尺寸。
- Node 测试：13 项通过，包括正式眼球/角膜/眼神法线的资产回归检查、口型连续性、表情权重、发音时保持眉眼情绪、避免咧嘴元音叠加笑容、10 秒音频/骨骼动画、皮肤权重归一化和真实帧率统计。
- Flutter release Web 构建通过。

这是第一段完整教学表演样片，尚不代表达到参考宣传片的动画美术质量。语音仍是本地合成音色，口型教学准确度未经过发音教师标定。

## 重建

在独立后台 Blender 进程中运行，避免修改用户已打开的场景：

1. `tools/export_snow.py -- --performance`，输入原始 `source-models/snow-source/Snow/snow_v4.2.blend`。生成骨骼、面部和 `work/performance-baked.blend`。
2. 以 `work/performance-baked.blend` 为输入运行 `tools/rebake_performance.py`，补充衣物间隙，输出当前 GLB 与可编辑的 `work/performance-refined.blend`。
3. 以 `work/performance-refined.blend` 为输入运行 `tools/refine_performance_expressions.py`，重建面部表演，保存中间场景 `work/performance-expressive.blend`，随后自动运行 `tools/restore_render_eyes.py`，生成最终 GLB 与 `work/performance-render-eyes.blend`。也可以单独对中间场景运行眼球恢复脚本。时间编排在 `assets/avatar/teaching-performance.js`。
4. 语音由 `tools/generate_performance_audio.ps1` 和 `tools/assemble_performance_audio.py` 生成。
5. `tools/flutter.ps1 build web --release --no-web-resources-cdn --no-pub`。

## 面部表演修订

前一版的笑容幅度被模型烘焙和播放权重重复减弱，脸颊、下眼睑参与不足，整体看起来没有表情。本版重做了左右嘴角与眉毛的目标姿势，增加脸颊抬起、带笑的眼睛和专注眼神；招呼、邀请和鼓励有不同的变化时机。待机保留轻微笑意，不在语音结束时退回空白脸。

眉眼情绪独立于发音保持；嘴部兼顾音素形状，尤其把 EE 的横向拉伸计入混合，避免与笑容叠加时嘴唇穿过牙齿。身体表演和全幅构图保持不变。静态表情与完整视频均经隐藏预览检查，视觉检查没有被自动测试或帧率结果替代。

`tools/refresh_performance_gaze.py` 是本轮从中间场景修正眼神的迁移脚本；全新重建的导出脚本已经包含修正，不需要额外运行它。

## 正式眼球恢复

前版错误地选用了 `GEO-snow-eye_anim`：该对象在原文件中 `hide_render=true`，使用三个纯色材质，是动画视口代理。原版 `GEO-snow-eyes` 和 `GEO-snow_eye_corneas` 未导出，虹膜纹理、法线和角膜层因此缺失。运行时统一把粗糙度提高到至少 0.38，也削弱了眼部光泽。这是导出选错对象与材质处理的问题，不能归因于 GLB 格式本身。

已恢复原版正式眼球及角膜网格，使用原始棕色虹膜贴图和法线贴图，分别缩放到 1024 和 512；新增独立透射角膜材质与一次性生成的摄影棚反射环境。眼神、点头与呼吸形变同步烘焙到眼球/角膜，保留对应的形变法线。原版不受 Blink 影响的球体保持体积，由眼睑网格遮挡；不人为把眼球压扁。生产模型不再包含代理眼球。

结果通过隐藏预览进行静态表情、完整动作和 Flutter 实页检查，30 秒性能报告如上。当前材质是针对 WebGL 的转换，并非原版 Cycles 多层着色器的逐节点复刻；仍不能承诺与官网离线渲染完全一致。Three.js 透射角膜会增加渲染工作量，真机仍需另外测量。

Snow Rig (CC) Blender Foundation | studio.blender.org
来源：https://studio.blender.org/characters/snow/v4/ ，许可：CC BY 4.0。
修改：贴图和材质简化、面部变形、运行时骨骼、原创教学动作、音频同步及 GLB 转换。

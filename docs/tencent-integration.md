# 腾讯云接入与联调

服务选择（2026-10-29 核实）：

| 用途 | 服务 |
| --- | --- |
| 教学配音 | 超自然大模型 2.0，流式文本接口 `stream_wsv2`，默认 YunLeo 403007 |
| 回忆回答转文字 | 实时 ASR V2，`16k_zh_en_2.0`，保留语气词、不配置答案热词 |
| 跟读反馈 | 口语评测新版 `soe/api`，英文词/句，苛刻指数暂设 2，尚未做儿童评分校准 |
| 教学口型时间 | 配音生成后调用新版 SOE 提取 PhoneInfos 时间；只用于素材对齐，不记作学习证据 |

## 本地运行

所有代码、配置与缓存均在本项目目录。Node 24 服务仅监听 127.0.0.1:5296。

1. 服务端配置放 `.secrets/tencent.json`，键为 `appId`、`secretId`、`secretKey`；也支持同名含义的 `TENCENT_APP_ID`、`TENCENT_SECRET_ID`、`TENCENT_SECRET_KEY` 环境变量。
2. 按用户最终选择使用主账号 API 密钥，存于服务端 `.secrets/` 并限制本机文件访问权限；不放在 Flutter assets、源码常量、浏览器或文档。
3. 运行 `node server.mjs`。Flutter Web 构建：`tools/flutter.ps1 build web --release --no-web-resources-cdn`。
4. 普通页面：`http://localhost:5296/`。独立口型测试页：`http://localhost:5296/avatar-dev/speech-test.html`（默认静音）。
5. `node tools/test-tencent.mjs` 执行少量真实付费调用，仅上传合成测试音频，不录制家人声音。报告保存到 `docs/tencent-integration/latest-report.json`。缺少凭据时退出，不伪造成功。

TTS、ASR 中国大陆、新版 SOE 后付费均已开通。2026-10-29 真实调用全部通过，详见 `tencent-integration/latest-report.json`：apple、英文句子和中文讲解的合成与音素对齐成功；合成的 “I like apples.” 被 ASR 正确识别，SOE 返回评分及 PhoneInfos。该测试证明接口连通与字段适配，不代表真人、儿童或嘈杂环境的准确率。

## 口型与费用

官方流式文本接口明确注明超自然音色暂不支持时间戳，实测字幕数组为空。当前以 SOE PhoneInfos 提取音素时间，映射到 Storm 口型并使用音频时钟驱动。12 秒英文演示获得 65 个音素区间。对齐属于实用近似，尚未经过人工逐帧唇形校准。

缓存键包括声音、文本、速度、语言、数据版本。首次生成需要 TTS 字符费用及一次 SOE 对齐费用，重复播放读取本地缓存。对齐失败保留原始音频，下次只重试对齐。缺失/未知音素会明确报错，不用旧音频的时间表套到新声音。

孤立音素及组合音标保留原先经过适配的素材，不送入跟读评测。固定 10 秒表演仍使用原配音以保留演出时间关系；普通单词教学、中文释义、课程讲解走云端新音色。

## 使用边界

跟读按钮只在词句跟读/回忆阶段出现，点击才请求麦克风，15 秒自动结束；“说完了”提前结束。切换单词/停止会终止录音、关闭麦克风并丢弃旧反馈。评分只作本次发音参考，不证明掌握词汇，不自动推进课程。回忆转写显示实际识别文字，不把它当发音评分。

当前接入目标为本机 Flutter Web 预览。Android/iOS 原生壳尚无已部署的 HTTPS 语音后端及原生麦克风权限接入，不宣称手机端已完成联调。Storm 本次性能记录见 `storm-integration.md`，不使用 Snow 的历史报告代替本次实测。

## 官方依据

- https://cloud.tencent.com/document/product/1073/108595
- https://cloud.tencent.com/document/product/1073/92668
- https://cloud.tencent.com/document/product/1093/131127
- https://cloud.tencent.com/document/product/1774/107497
- https://cloud.tencent.com/document/product/1774/107386

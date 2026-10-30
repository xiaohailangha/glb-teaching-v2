# 私有项目版本管理

代码仓库为 `xiaohailangha/glb-teaching-v2`（Private）。原有公开仓库 `mouth_teacher` 不改动。

`main` 保存现有 Flutter + Three.js 测试基线；`feat/flutter-scene` 保存新引擎验证工作。先提供独立 Web 测试入口，再依据用户测试决定 Android 包与合并。模型继续内置原生安装包。

提交范围包括客户端、语音服务端源码、测试、部署工具和项目文档。`.secrets`、本地环境文件、私钥、SDK、依赖缓存、打包产物、临时录音/视频、原始 Blender 工程均不提交。GLB 成品用 Git LFS 版本化，克隆时需安装 Git LFS 并执行 `git lfs pull`。

密钥仍通过原有本地 `.secrets` 文件或服务端环境变量配置；不要将其放入前端或 Git。首次提交和后续推送需先扫描已暂存文件，不只依赖忽略列表。

Flutter Scene 验证使用项目内独立 SDK，现有 `D:\flutter` 保持原版本。运行说明随验证完成更新；`work/` 中的本地 SDK 与临时工具不属于代码仓库。

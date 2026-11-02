# Snow Speaks

当前应用使用 Flutter 原生界面和 Flutter GPU / flutter_scene 人物渲染，服务端提供账号、课程、学习统计和腾讯语音能力。

线上入口：https://49.233.179.83/scene/

## 目录

| 目录 | 用途 |
| --- | --- |
| `scene-preview/` | 唯一的应用工程、资源及 Flutter 测试 |
| `services/`、`server.mjs` | 账号、学习、语音与资源 API |
| `data/` | 服务端课程目录 |
| `tools/` | 构建、部署、资源制作与验证 |
| `test/` | 服务端、启动流程、模型与动作回归 |
| `assets/` | 字体原件与历史依赖许可 |
| `docs/` | 设计、许可及历史验收记录 |

历史文档中的旧启动命令不再适用，以此说明为准。`.secrets/` 保存凭据，`work/` 保存 SDK 与制作中间文件，`var/` 保存本地持久数据，`cache/` 保存可再生缓存，`source-models/` 保存原始 Blender 素材；不要将这些目录作为无用代码批量清理。

## 开发与验证

在仓库根目录执行：

```powershell
npm ci
npm run check
npm test
.\tools\flutter-scene.ps1 analyze
.\tools\flutter-scene.ps1 test
.\tools\flutter-scene.ps1 build web --release --no-web-resources-cdn --no-pub --base-href=/scene/ --no-wasm-dry-run
npm start
```

本地入口：http://localhost:5296/scene/ 。构建后也可双击 `启动预览.cmd`，根路径自动跳转到当前应用。Flutter 包装器使用 `work/flutter-scene-sdk` 并临时映射 `V:`，不能并行运行。

## 发布与资源维护

- `tools/deploy-scene-preview.mjs`：更新现有服务器 `/scene/` 与 API，包含备份和失败回滚。
- `tools/publish-scene-assets.mjs`：模型变化并构建后发布私有 COS 资源。
- `tools/publish-scene-apk.mjs`、`tools/verify-scene-apk.ps1`：Android 发布与检查。
- `tools/export-course-catalog.mjs`、`tools/prepare-*.mjs`：课程目录、音频与图片制作。
- `tools/export_storm.py`、`tools/storm_motion.py`、`tools/storm_materials.py`：Storm 模型制作链路。
- `scene-preview/lib/core/avatar/scene/authored_tracks.dart`：当前人物动作数据的唯一编辑源。
- `tools/generate-storm-bind-fixture.mjs`：从当前模型生成关节绑定基准。已认可的动作采样保留在 `scene-preview/test/fixtures/three-math-parity.json`，用于校验 Dart 实现，不依赖旧 JavaScript 运行代码。
- `tools/subset-scene-fonts.py`：界面文字与音标字体子集生成。

旧 WebView 应用、独立 Three.js 演示入口、临时网关和录屏/基准上传接口已移除。旧版全站覆盖发布脚本也已删除，避免覆盖当前应用。本次整理不删除线上历史发布目录与账号数据。

## 素材许可

Storm Rig (CC) Blender Foundation | studio.blender.org

- 来源：https://studio.blender.org/characters/storm/v1/
- 许可：https://creativecommons.org/licenses/by/4.0/
- 修改：贴图压缩与图集、材质简化、表情及姿态烘焙、GLB 格式转换。
- 应用“我的”页面底部保留署名和许可链接。
- Three.js 数学参考的 MIT 许可及字体 OFL 许可保留在素材目录。

## 正式存储与课程发布

- 云服务器：Web 程序、API、SQLite 账号和学习记录。App 数据在 `/var/lib/snow-speaks-app`，管理端数据在 `/var/lib/snow-speaks-admin`，缓存在 `/var/cache/snow-speaks-app`。环境变量分别为 `SNOW_DATA_DIR`、`SNOW_ADMIN_DATA_DIR`、`SNOW_CACHE_DIR`。
- 私有 COS：模型分块、课程 JSON、音频、口型时序和插图。课程使用内容哈希版本目录；登录后领取短期签名清单，下载验证 SHA-256，学习期间固定版本。Web 发布排除人物二进制，原生包保留人物模型及启动静音；少量插图保留启动回退。
- 私有广州备份桶：每日加密快照，保留 30 天。包含三个数据库、账号加密密钥和课程版本索引；每次上传后下载、解密并验证数据库。备份加密密钥单独保存在 `.secrets/project-backup.key`，不得随备份上传、提交 Git 或丢弃。
- 管理端通过受保护 API 展示同一版本课程素材；“资源与发布”支持发布、回退及备份状态查看。录音只用于本次识别，不作永久保存。

课程修改后执行 `node tools/export-course-catalog.mjs`，再运行 `node tools/publish-course-assets.mjs --upload` 与 `node tools/install-storage-release.mjs`。首次安装会激活初始版本，后续仅暂存，由管理端明确发布。已发布版本不得覆盖。

首次服务器迁移使用 `node tools/migrate-storage.mjs`；它先停止两端服务、校验数据库、复制并比对哈希，保留原目录快照，再建立兼容链接。日常程序发布不搬动数据库。

备份任务为 `snow-project-backup.timer`，每日北京时间 03:15 后执行；可通过 `systemctl start snow-project-backup.service` 手动执行。服务器带上述数据目录环境变量执行 `node tools/backup-project.mjs --verify-latest` 可独立下载和验证最近备份。恢复时应先停服务并保存现有数据库，使用独立密钥解密、校验全部文件，再恢复账号库及其配套密钥、学习库、管理库、课程版本目录；不得混用不同快照。

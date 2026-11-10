# Snow Speaks App

唯一 App Git 仓库：D:/AI语言训练/scene-preview。Flutter 源码在 scene-preview/，接口服务在 ../server，管理端在 ../admin，各自独立维护。

- `npm run build`：使用本仓库 Flutter SDK 构建网页，生成版本化入口和 gzip 静态资源。
- `npm start`：本地网页 http://127.0.0.1:5295/scene/；API 代理到 5296，可用 APP_API_ORIGIN 设置。
- `npm run check`、`npm test`：工具检查；`tools/flutter-scene.ps1 test --no-pub`：Flutter 测试。
- `npm run deploy`：校验并打包网页；`npm run deploy -- --apply`：发布网页到现有 /scene/，保留备份。
- API 另在 server 项目执行 npm start / npm run deploy；网页发布不会重启或发布 API。
- `启动预览.cmd`：打开本地 App，使用前先构建，并在接口仓库启动 API。

人物使用 Flutter Scene / WebGL2；手机背景通道修复、浏览器异步摘要、模型缓存校验和着色器预热均在当前源码。当前两课版本由 release.json 标识，测试内容是 scene-preview/test/fixtures/content 的固定样例，正式课程归接口项目维护。

work 是本地 SDK 和生成缓存，outputs 是验证产物，source-models 是模型原件，.secrets 为本地发布凭据，均不提交。正式学习进度由接口项目保存。

Storm Rig (CC) Blender Foundation：https://studio.blender.org/characters/storm/v1/ ，CC BY 4.0：https://creativecommons.org/licenses/by/4.0/ 。保留应用内署名、素材及字体许可。

# Snow Speaks App

唯一 App Git 仓库：D:/AI语言训练/scene-preview。Flutter 源码在 scene-preview/，接口服务在 ../server，管理端在 ../admin，各自独立维护。

- `npm run build`：使用 D 盘独立 Flutter SDK 构建网页，生成版本化入口和 gzip 静态资源。
- `npm start`：本地网页 http://127.0.0.1:5295/scene/；API 代理到 5296，可用 APP_API_ORIGIN 设置。
- `npm run check`、`npm test`：工具检查；`tools/flutter-scene.ps1 test`：Flutter 测试。
- `npm run deploy`：校验并打包网页；`npm run deploy -- --apply`：发布网页到现有 /scene/，保留备份。
- API 另在 server 项目执行 npm start / npm run deploy；网页发布不会重启或发布 API。
- `启动预览.cmd`：打开本地 App，使用前先构建，并在接口仓库启动 API。

人物使用 Flutter Scene / WebGL2；手机背景通道修复、浏览器异步摘要、模型缓存校验和着色器预热均在当前源码。当前两课版本由 release.json 标识，测试内容是 scene-preview/test/fixtures/content 的固定样例，正式课程归接口项目维护。

Flutter SDK 与依赖缓存位于 D:/sdk/snow-speaks，可用 SNOW_FLUTTER_TOOLS 指定工具目录。网页成品和发布包在工具目录的 scene-preview-output，本地预览与发布共用该位置。work 与 outputs 保存本地验证记录。人物 GLB、预编译人物和 Blender 制作文件在 D:/AI语言训练/卡通人物/Snow Speaks。模型验证从 models 读取 GLB，模型发布从 compiled 读取预编译文件。App 保留人物清单和着色器，运行时从 COS 下载人物。旧课程内容在 ../server/data/legacy-course-assets，App 只保留测试所需的样例。Git LFS 历史缓存位于 D:/sdk/snow-speaks/scene-preview-lfs。.secrets 为本地发布凭据。可用 tools/flutter-scene.ps1 clean 清理项目内的 Flutter 构建缓存。正式学习进度由接口项目保存。

Storm Rig (CC) Blender Foundation：https://studio.blender.org/characters/storm/v1/ ，CC BY 4.0：https://creativecommons.org/licenses/by/4.0/ 。保留应用内署名、素材及字体许可。

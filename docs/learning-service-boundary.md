# APP 与独立管理端的边界

管理端已移到同级独立仓库 `../admin`，APP 不依赖该目录，安装、构建、测试和发布均不需要管理端源码。

APP 持有学员账号、课程、语音、学习记录及云端断点。`services/learning-http.mjs` 和 `services/learning-store.mjs` 为 APP 功能，不包含管理员登录、账单或 Vue 页面。数据保存在 work/learning-private/learning.sqlite，独立定时备份。

`node tools/export-course-catalog.mjs` 根据 APP 课程生成 data/course-catalog.json，随 APP 后端发布。管理端通过接口查看最新课程，无需复制课程源文件。

## 内部管理契约 v1

路径 `/internal/management/v1/` 仅接收 loopback 且带匹配 Bearer 令牌的请求。令牌从忽略的 .secrets/management-bridge.json 读取。Nginx 必须阻断 `/internal/`。没有令牌时仅内部管理查询不可用，不影响 APP 学习接口。

- GET catalog、overview、users、daily、events、users/:id、system：课程和运营数据。
- POST users/:id：action 为 disable、enable、revoke，通过 APP 账号服务操作。
- 查询参数 from/to 使用北京时间日期；q/page/sort/export 与管理端契约保持一致。
- 学员仍使用原 `/api/auth/learning/batch` 与 `/api/auth/learning/state`，无需修改 Flutter 客户端。

管理员、腾讯账单、管理审计和部署属于另一个项目。本仓库历史提交保留已移出内容，不改写 Git 历史。

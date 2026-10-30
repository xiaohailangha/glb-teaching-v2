# COS 模型分发：2026-10-30

**同日后续：用户已要求取消测试账号密码，站点现在直接访问，无需 family 或 admin 登录。私有桶、短期签名、校验、缓存和服务器回退保持原配置；下文测试账号/清单 401 是此前验证的历史状态。**

已完成线上接入，测试入口仍是 https://49.233.179.83/ ，原 family 测试账号不变。没有操作 ExtraVM VPS。

## 已配置资源

- 控制台核实的付费包：大陆通用标准存储 **10GB，一年**，到期 2027-10-30 23:59:59，手动续费。不是之前购买页截图的 100GB。存储包不等于下载流量包；公网下行、请求等按账户实际计费规则结算。本次没有购买额外套餐、启用 CDN 或全球加速。
- 存储桶：`glb-teaching-assets-1252505198`，北京 `ap-beijing`，私有。
- 模型前缀：`models/storm/a727ba3e745250b1502a6aed4ba135f6b5d534c0f8da2b81cb7ca87757354af3`。
- 147 个 gzip 分块 + manifest.json，模型原始 153,334,024 字节，压缩分块合计 93,780,088 字节。每块最多 1MiB 解压后大小；未降低模型画质/动作精度。
- 服务端加密 SSE-COS AES256；CORS 只允许 `https://49.233.179.83` 的 GET/HEAD，支持 Range，暴露长度/编码/版本头。
- 桶未开放公共读写。COS 默认域名用于 fetch 下载，不需额外购买域名；私有请求必须附有效签名。

## 运行流程

已通过测试账号验证的页面请求 `/api/assets/model-manifest`。Node 后端用 STS 申请仅限当前模型前缀的 `cos:GetObject` 权限，一小时有效，生成约 55 分钟有效的下载地址。签名清单缓存至剩余五分钟再刷新；并发请求共用一次申请。返回浏览器的只有临时签名 URL，不返回长期密钥或临时 SecretKey。

浏览器四并发加载，逐块校验长度与 SHA256，最终校验整模 SHA256。按模型 SHA256 写入 CacheStorage；签名过期重新获取清单后仍可复用同版本本地字节。模型升级自动使用新版本，成功后清理旧的本项目模型缓存。浏览器拒绝缓存/配额不足不阻止学习。清单或 COS 下载失败则回退已部署的服务器分块。

缓存可能被系统清理，尤其手机存储不足、无痕模式；重复打开并不永远保证零流量。当前仍需要服务端可访问以取得清单，未实现离线课程或完整离线 App。

配置 `.secrets/cos-assets.json` 仅在本地和后端，服务器 glbapp:glbapp 600；既有腾讯凭据仍在 `.secrets/tencent.json`。systemd 增加 `COS_ASSETS_ENABLED=true`；本地开发默认关闭 COS，使用本地模型。Nginx 精确代理清单接口，保留测试账号鉴权及跨站保护。

## 实际验证

- Flutter Web release 重新构建成功（有既有 CupertinoIcons 字体引用警告）；49 项 Node 测试通过，语法检查通过，npm audit 为 0 个漏洞。
- `tools/test-cloud-preview.mjs`：10 组线上回归通过，含真实腾讯 TTS/口型时间线和既有服务器分块首尾字节；没有重复录音或调用真人评测。
- `tools/test-cos-preview.mjs`：5 组通过，含未登录清单 401、长期密钥未暴露、无签名模型 403、允许站点 CORS/解压 SHA256、其他站点不能获得跨域读取许可。
- 隐藏 IAB 打开正式 Flutter 页面，147 块全部来自 COS，网络下载跨度 **5,293ms**，没有触发服务器回退。此前相同电脑通过服务器下载的记录为 153,020ms。这里比较的是模型下载，不是完整首屏时间、解析时间、FPS 或手机体验。
- 重新打开后 147 块均命中 CacheStorage，**COS 和服务器模型请求均为 0**，人物正常显示。
- 点击“开始学习”后，引导、单词示范、邀请跟读三次 TTS 与音频下载全部 200，页面自然进入“轮到你了，试着说一遍”；未开启麦克风。结果 `browser-teaching.json`。
- 实图 `preview.png`，下载与缓存结果 `browser-first-load.json` / `browser-repeat-load.json`，公网接口结果 `latest-verification.json`。手机网络速度、Safari 缓存配额和设备帧率仍需真机测试。

## 维护与恢复

1. `tools/configure-cos-assets.mjs inspect` 只读列桶；`configure` 会为当前本地 Storm 模型创建/更新项目专用桶 CORS 和分块，写本地 COS 清单。不要为了查询重复上传。
2. 依赖锁定 `cos-nodejs-sdk-v5@3.0.0`、`tencentcloud-sdk-nodejs-sts@4.1.100`。公共 SDK 的 uuid 依赖覆盖为 11.1.1，使用到的 v4 接口兼容，消除旧版本审计告警。所有后端依赖必须随发布包部署。
3. `tools/build-cloud-release.mjs` 为白名单打包工具，不包含 `.secrets`。本次发布包 `work/cloud-deploy/cos-release.tar.gz`，上传到 `/root/glb-cos-release.tar.gz`。
4. 更新脚本 `tools/deploy-cos-update.sh` 仅匹配此腾讯实例主机名，先完整备份旧应用与配置，再暂存/检查依赖、重建 gzip、保留服务器回退分块、切换新版并重启项目服务。不重装服务器。
5. **本次备份路径：`/opt/glb-backups/before-cos-20261030T014211Z`**。`app` 是旧应用完整副本（包含原密钥，父目录权限 700），`nginx.conf` / `service` 是旧配置。另有 `previous-web`。暂存目录和发布包只供本次运维，没有公开。
6. 必须回滚时，停止 glb-teaching，把当前 `/opt/glb-teaching` 重命名留存，从该备份 `app` 复制还原到原路径，恢复 nginx.conf / service，执行 nginx -t、systemctl daemon-reload、启动项目服务并 reload nginx，然后运行公网回归。旧版没有 COS 依赖，模型回到服务器下载。不要删除用户学习数据；本版本尚无正式注册/学习进度数据库，后续若新增必须先另行备份数据。
7. 临时 SSH 授权通过 `tools/prepare-deploy-access.mjs` 创建，收尾用 `tools/deploy-cloud-cleanup.sh` 移除，仅保留原有其他公钥。不把凭据写入交接聊天或前端资源。

原 Let’s Encrypt IP 证书及自动续期 timer 保持启用；以后改为域名入口时应同步更新 Nginx origin 校验和 COS CORS。

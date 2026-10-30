# 腾讯云 Web 测试部署

**最新访问方式：2026-10-30 用户要求取消测试账号密码，现已移除本站 HTTP Basic 验证，直接打开 https://49.233.179.83/ 即可测试。下文账号保护的验证记录属于历史。当前 `.secrets/cloud-preview.json` 仅记录 origin 和 accessMode=public。已验证无登录页面、语音状态、模型与 COS 清单均可访问，服务端密钥仍不可下载；回滚配置在 `/opt/glb-backups/before-direct-preview-20261030T015449Z`，验证见 direct-access-verification.json。**

**同日 COS 后续更新已上线。模型现在优先走北京私有 COS，服务器分块保留为回退。当前配置、实测速度、更新与回滚流程以 `../cos-integration/README.md` 为准；下文首次部署和 153 秒下载记录保留作历史。**

2026-10-30 用户购买了新的腾讯云轻量服务器并明确要求部署。此授权只恢复**新腾讯云机器**的部署；ExtraVM 东京 VPS 继续不动。以下取代旧交接中“没有购买腾讯云/所有部署暂停”的相应状态。

## 入口与资源

- 访问地址：`https://49.233.179.83/`，直接使用公网IP，无需把未备案域名解析过去。
- 私人内部测试，HTTP Basic验证，账号和测试口令在本地 `.secrets/cloud-preview.json`。不要把腾讯云主账号/API密钥当作此测试账号。
- 实例：`lhins-52h0i09a`，北京三区，2核4GB、60GB SSD、5Mbps、500GB/月套餐，Ubuntu24.04；面板名Ubuntu-LLqK。
- HTTPS是Let's Encrypt可信IP证书，不是自签证书。约6天有效，每天检查两次自动续期并reload Nginx。实际有效期用 `openssl x509` 查看。
- 该入口为受控测试；未来公开服务仍需按大陆网站要求准备域名备案。IP证书不是免除备案的通行证。

## 部署布局

- `/opt/glb-teaching/build/web`：已有Flutter release文件，未上传项目源模型、文档和私人录音。
- `/opt/glb-teaching/server.mjs`、`services/`：Node语音后端，仅监听127.0.0.1:5296。
- `/opt/glb-teaching/.secrets/tencent.json`：服务端腾讯凭据，glbapp所有、600权限。绝不进入静态文件目录。
- `/opt/glb-teaching/work/tencent-cache`：生成音频与口型缓存，可写，其余应用由systemd限制写入。
- `/opt/glb-runtime/node`：Node24 LTS官方Linux运行时，安装时与官方SHASUMS256校验，当前v24.22.2。
- `/opt/glb-runtime/certbot`：独立Python环境，当前Certbot5.9.0。
- `/etc/nginx/sites-available/glb-teaching`：站点配置，80仅ACME/HTTPS跳转，443带密码验证。原新机默认站点链接移存`/root/glb-nginx-default.disabled`。
- `/etc/nginx/glb-passwords`：测试账号口令哈希，root:www-data、640。
- systemd服务`glb-teaching.service`、`glb-cert-renew.service`与timer；语音后端低权限glbapp、自启动、异常重启。
- 只给**该新实例**新增443入站；22、80是购买后的原有规则。没有改ExtraVM防火墙/路由/服务。

## 模型传输

- 原模型153,334,024字节，未为了上线降模型精度或改动画。
- 发布时生成147个1MiB分块，gzip总大小91,811,614字节（约87.6MiB），避免整个大文件受一次超时影响。
- Nginx在原模型HEAD返回大小/分块大小/版本ETag；`?previewPart=N`提供对应块及一致版本头，现有model-download.js用3并发下载和重试。
- JS、WASM、模型等预压缩；浏览器缓存需校验版本，不让同名旧人物永久滞留。
- 5Mbps带宽下首次模型下载理论就需约2.5分钟，现实还包括页面/解析和设备性能，不能声称秒开。后续可评估COS/资源进一步优化，尚未配置COS分发。

## 维护工具

- `tools/tencent-deploy-api.mjs`：明确锁定此实例的腾讯API/TAT辅助，不打印本地密钥。
- `tools/prepare-deploy-access.mjs`：通过TAT建立项目临时上传SSH公钥（不重置系统密码）；部署后应移除远端临时授权。主机指纹通过腾讯TAT取得并存`.secrets/lighthouse-known-hosts`，SSH使用StrictHostKeyChecking=yes。
- `tools/build-cloud-release.mjs`：打包build/web、server.mjs、services、package/lock及后端node_modules，写入work/cloud-deploy/release.tar.gz，凭据单独加密SSH上传。
- `tools/deploy-prepare.sh`：新机器运行环境初始化。已经部署后不要无故重复安装或覆盖环境。
- `tools/deploy-cloud-install.sh`：**仅首次部署**，存在server.mjs即停止，避免覆盖旧版本。
- `tools/deploy-cloud-configure.sh`：刷新本站Nginx模板及模型元信息，先nginx -t再reload。
- `tools/glb-nginx.conf`、`tools/glb-*.service`、`tools/glb-cert-renew.timer`：配置源码。
- `tools/test-cloud-preview.mjs`：公网HTTPS、鉴权、私密文件阻断、跨站拒绝、模型首尾块字节/版本、错误录音和一次真实TTS/口型测试。TTS可能少量计费，缓存命中则不重新合成。

更新部署需保留现有`.secrets`和work缓存，先构建/备份，再更换发布文件、重新生成分块与gzip、验证并reload。不能直接将整个项目目录同步到公网根目录。当前不是完整CI/CD流水线。

## 本次验证与限制

- 本地43个Node测试全部通过，npm run check通过；没有改Flutter/Dart或人物源码，因此复用已有Web release，没有重新构建原生App。
- 公网测试脚本已通过全部9组检查，见latest-verification.json。包括正常证书验证、401访问保护、源码/凭据不可下载、跨站请求403、模型分块版本与本地原字节一致、腾讯apple配音及口型。
- 后续检查增加“从外部链接导航正常、跨站POST拒绝”，最终公网回归10组通过；另用合成的“I like apples.”通过新服务器实际调用ASR和SOE成功，未录制用户声音。
- Certbot真实执行`renew --dry-run --cert-name glb-teaching-ip --run-deploy-hooks`，全部模拟续期成功，自动续期timer已启用。证书本次到期时间2026-11-05 16:21:40 UTC，由自动续期维护。
- 隐藏IAB实际打开正式Flutter页面，Storm完整渲染，点击“开始学习”后引导/示范/邀请语音请求与音频下载均返回200。页面secureContext=true，麦克风API可用，但没有实际开启麦克风。
- 浏览器资源时序实测：147个分块、解压后153,334,024字节，首次模型下载跨度153,020ms（约2分33秒）。这是真实桌面网络结果，不是手机速度或帧率保证。实图preview.png。
- iPhone真实麦克风授权、真人跟读/不同口音、手机90/120FPS仍需手机验证，云端部署不等于这些验收已完成。
- 公网入口独立于用户电脑运行；服务器停机、欠费、证书续期失败仍会影响可用性。
- 收尾已完成：删除远端/root下两份暂存凭据，移除本项目临时SSH公钥授权，保留原有密钥。应用凭据600、口令哈希640；后端只监听127.0.0.1:5296。后续维护可通过已授权的腾讯TAT，必要时重新建立临时上传通道。

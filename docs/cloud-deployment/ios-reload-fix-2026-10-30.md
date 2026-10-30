# iPhone 整页重载修复（2026-10-30）

用户在 iPhone 13 Pro Max 的 Safari 和微信浏览器报告：人物出现后整个网页反复重新加载；电脑正常。未取得设备崩溃日志，不能将内存压力确定为已证实根因。

源码只在旧 service-worker 清理及用户点击重试时调用 reload；没有正常人物 ready 后主动重载的流程。移除启动阶段自动 reload，清理注册失败也继续启动 Flutter。

模型审计：原始 GLB 153,334,024 字节；普通纹理估算含 mipmaps 272 MiB，表情 Float32 纹理不计行填充约 144.82 MiB；以上不包含 CPU 副本、渲染缓冲或 Flutter。不能把下载压缩体积等同于运行内存。

iOS（含微信 UA、触屏 iPad）启用以下预算：

- 19 个带 morph 的网格选择 RGBA16F 存储，仍保留所有顶点、位置/法线表情及动画；估算表情纹理约减半。桌面保持 Float32。vendored Three.js WebGLMorphtargets 的补丁由 geometry.userData.morphTextureHalfFloat 显式启用，升级 Three.js 时须保留或重新验证。
- 6 张头发纹理从 2048 限制到 1024，脸部 2048 与眼睛纹理保持，模型源文件、COS 版本不变。纹理估算从 272 MiB 降至 176 MiB。
- DPR 上限 1，阴影上限 512，关闭 MSAA，角膜 transmission 缓冲比例 0.5；高帧率设置仍可请求，不代表设备保证达到。
- 解析后释放 GLB 和 parser 引用，渲染前让出事件循环；相同尺寸/像素比不再重复设置画布。WebGL context lost 显示可手动重试的错误，不主动刷新。

55 个本地 Node 测试、语法检查和 Flutter Web release 构建通过；构建仍有已有 CupertinoIcons 引用警告。新增 6 个回归测试覆盖 iOS 判断、共享纹理、脸部细节保留、帧率预算、真实模型半精度误差及 SW 清理异常。抽样实际 morph 值验证位置误差小于 0.2mm 模型单位、法线误差小于 0.002；没有宣称逐音素教学已校准。

静态更新仅发布 flutter_bootstrap.js、avatar.js、render-quality.js、mobile-memory.js 和 vendored three.module.js 及其 gzip；没有改后端、COS 模型、证书或 Nginx 配置。备份 `/opt/glb-backups/before-mobile-memory-20261030T022120Z`；回滚时从备份恢复这五项及 gzip，并移除备份中不存在的 mobile-memory.js。无需重启 Node 或 Nginx。部署临时 SSH 公钥已移除，原有公钥保留；ExtraVM 未操作。

已通过 10 组线上回归和 5 组 COS 检查。隐藏桌面 IAB 使用 iPhone UA 验证手机分支，记录 enabled=true、19 个半精度网格、6 张纹理缩小，人物正常渲染且无控制台错误；此为 Chromium 分支回归，不是 iPhone/WebKit 内存限制或真机稳定性验证。等待用户在原 iPhone 复测。

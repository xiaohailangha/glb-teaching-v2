# Android 对照测试包：0.1.1+2

用户提供的测试手机为 S98Pro、Android 12。当前发布 ARM64 release 测试包，最低 Android API 24（Android 7.0），使用现有 Flutter + WebView + Three.js；未迁移 flutter_scene 或升级 Flutter SDK。

- 下载： https://49.233.179.83/downloads/glb-teaching-0.1.1-arm64.apk
- 本地文件：`outputs/android/glb-teaching-0.1.1-arm64.apk`，115,275,896 字节（约 109.94 MiB）。
- SHA256：`66637fea36b0102b9b858f2154384c0e17777813306e41b73ddb4b3ed58bb406`。
- 包名仍为 `com.local.snow.snow_speaks`，显示名 glb模型能力，build number 2；使用既有本地 debug key 签名的非 debuggable release 测试构建，不是商店正式签名。
- Storm、渲染代码、基础教学音频内置；模型 SHA256 与现有原件一致。线上腾讯语音需要联网。

为使原生包能测语音，LocalAssetServer 增加精确白名单的腾讯语音 HTTPS 转发，固定指向现有服务器；客户端请求/音频仍走本地同源路径，没有将腾讯长期密钥放入包内。限制请求来源、Host、路径、方法与 650 KiB 请求大小，不转发授权/ Cookie。COS 清单不在原生白名单，保持加载包内模型。

补充 Android RECORD_AUDIO 声明和仅点击跟读后触发的运行时权限通道。WebView 只允许本地页面请求麦克风，不申请摄像头；用户拒绝时回到已有录音错误反馈。真实设备录音尚未验证。

验证：20 项 Flutter 测试通过（新增本地资源/语音转发、查询参数、跨站拒绝与超大录音拒绝），analyze 无问题，ARM64 release 构建通过。首次 Kotlin 增量编译遇到 C:/V: 跨盘缓存问题，工具回退后构建成功；未修改全局 Gradle/SDK。apksigner 验签通过，aapt 确认 ARM64、minSdk 24、录音权限及非 debuggable；打包文件无 .secrets 配置，扫描代码未发现长期腾讯 SecretId/SecretKey。

下载地址 HTTPS HEAD 与首尾 Range 206 验证通过；服务器核对完整 APK SHA256。仅新增独立 downloads 文件，未修改线上教学代码、Nginx 配置、证书或现有服务，ExtraVM 未操作。上传使用的临时 SSH 授权已移除。

ADB 列表出现 S98Pro 但状态 offline，因此本次没有安装、启动或测量该真机；帧率、发热、麦克风系统授权和真实发音反馈等待用户测试。先用默认高档/自动适应运行 2 分钟，记录设置面板 FPS，再用中档、低档对比。课程样板入口为演示库 → 课程表演 · apple。

构建：`tools/flutter.ps1 build apk --release --target-platform android-arm64 --no-pub --build-name 0.1.1 --build-number 2`。校验工具 `tools/verify-android-preview.ps1`，报告见 `outputs/android/apk-verification.json` 与 `download-verification.json`。

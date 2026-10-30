# 临时外网测试

状态：2026-10-28 用户要求暂停外网测试，通道与只读服务均已停止。

历史地址（已停用）：https://temporal-mechanism-duck-moms.trycloudflare.com/

临时 Cloudflare Quick Tunnel 使用 QUIC，仅转发到本机 127.0.0.1:5297 的只读静态服务。只提供 build/web 文件，不接入 5296 开发服务的录制和性能报告写入接口。GET/HEAD 可用，其他请求返回 405；开发接口和项目文件返回 404。

保持电脑开机、联网且不休眠。重启通道会换地址。知道地址的人可以访问页面；这是临时测试链接，非固定域名。

停止外网：在项目目录运行 `powershell -ExecutionPolicy Bypass -File tools/stop-public-preview.ps1`。脚本会核对进程身份，只停止本项目的外网通道和只读服务，保留原有本地开发服务。

进程状态：work/tunnel/origin.pid、work/tunnel/tunnel.pid。日志：work/tunnel/origin.err.log、work/tunnel/tunnel-quic.err.log。cloudflared 从 Cloudflare 官方 GitHub Releases 下载，未安装系统服务或开机启动，未修改代理或防火墙设置。

网页资源传输支持 gzip。Flutter CanvasKit 从本站加载。原始中文字体保留在 assets/fonts/NotoSansSC.ttf，实际打包 NotoSansSC-ui.ttf（232456 字节）；新增界面文字后先运行 tools/subset_ui_font.py 再构建。字体工具位于 work/font-tools。

恢复通道需要重新启动 `node tools/public-preview.mjs` 和 `work/tunnel/cloudflared.exe tunnel --url http://127.0.0.1:5297 --protocol quic --no-autoupdate`，并使用日志中新生成的地址。

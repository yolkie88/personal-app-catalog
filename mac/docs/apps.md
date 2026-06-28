# macOS 应用说明

本文件记录 mac 侧应用为什么值得保留、平时做什么、哪些恢复内容必须手工处理。它不是某台机器的软件快照；已安装软件只是维护输入，最终进入清单的是长期认可且有稳定来源的条目。

## core

| 应用 | 用途 | 保留理由 | 恢复边界 |
|---|---|---|---|
| Firefox / Chrome | 浏览器 | Firefox 作为开放默认浏览器，Chrome 保留兼容性和账号生态 | 浏览器账号、同步和扩展登录手工恢复 |
| Bitwarden | 密码管理 | 跨平台、可恢复性强 | 主密码、2FA 和 vault 不入库 |
| Keka | 压缩解压 | 免费精致，mac 原生体验好 | 无明显边界 |
| LocalSend | 局域网传输 | 跨 Windows/macOS/手机传文件方便 | 设备发现和局域网权限按网络环境处理 |
| Maccy | 剪贴板历史 | 开源轻量 | 剪贴板历史不入库 |
| Itsycal | 菜单栏日历 | 轻量补足系统日历入口 | 日历账号跟随系统账户 |
| Ice | 菜单栏图标管理 | 开源替代 Hidden Bar，适合菜单栏常驻工具多的 Mac | 菜单栏排列按设备调整 |
| Stats | 菜单栏系统监控 | 开源，适合长期开机观察负载、温度和网络 | 历史数据不入库 |
| Raycast | 启动器和命令面板 | mac 效率入口，生态成熟 | 账号、扩展配置和 AI key 手工恢复 |
| JetBrains Mono Nerd Font | 终端字体 | 统一终端和 prompt 图标显示 | 字体渲染按终端调整 |

## agentic-dev

| 应用 | 用途 | 保留理由 | 恢复边界 |
|---|---|---|---|
| VS Code | 主 GUI 编辑器 | 跨平台、扩展生态强 | Settings Sync、账号、私有扩展源手工恢复 |
| iTerm2 | 终端 | 本机已安装且成熟稳定 | Profile、Hotkey、SSH 书签手工恢复 |
| ChatGPT / Claude | AI 桌面入口 | 与 Codex/Claude Code 工作流互补 | 登录和本地会话不入库 |
| Codex App | Codex 桌面入口 | 本机已安装，但当前不走 Homebrew cask | 按官方渠道/App Store 手工恢复，登录状态不入库 |
| mise | 运行时管理 | Node/Python/K8s 工具链统一入口 | 版本选择写清单，项目依赖跟随项目 |
| gh / just / direnv / zoxide / starship / delta / lazygit / neovim | CLI 工作流 | 和 WSL 工具层保持一致，mac 本机开发可用 | 登录、历史、项目配置不入库 |

## daily

| 应用 | 用途 | 保留理由 | 恢复边界 |
|---|---|---|---|
| Obsidian / Logseq | 笔记和知识库 | 本机已安装，数据目录可跨设备同步 | vault/graph 数据位置手工指定 |
| MarkEdit / Typora | Markdown 写作 | MarkEdit 免费开源，Typora 是已使用的精致付费工具 | Typora 授权手工恢复 |
| Skim / IINA | PDF 和媒体播放 | mac 原生、轻量、体验好 | 媒体库不入库 |
| Folo | 信息流阅读 | 本机已安装，适合日常信息浏览 | 账号和订阅源按应用恢复 |
| Motrix | 下载管理 | 开源下载器，适合大文件任务 | 下载目录和历史不入库 |

## desktop-enhance

| 应用 | 用途 | 保留理由 | 恢复边界 |
|---|---|---|---|
| Rectangle / AltTab | 窗口管理和切换 | 免费开源，补足 macOS 默认窗口体验 | 辅助功能权限手工授予 |
| BetterDisplay | 显示器管理 | 本机已安装，Mac mini 外接显示器场景更强于基础亮度工具 | 付费授权和显示器布局手工恢复 |
| LinearMouse / Mos | 鼠标滚动和加速度 | 本机已安装，外接鼠标体验关键；优先保留开源免费方案 | 输入监控/辅助功能权限手工授予 |
| OnlySwitch | 菜单栏快捷开关 | 开源，适合长期开机机器快速切换系统状态 | 权限按功能手工授予 |
| PixPin | 截图标注 | 本机已安装，跨平台截图体验好 | 云同步/历史不入库 |
| PopClip | 选中文本动作 | 本机已安装，mac 原生效率工具 | 扩展和授权手工恢复 |

## home-hub

| 应用 | 用途 | 保留理由 | 恢复边界 |
|---|---|---|---|
| Tailscale | 私有网络 | 家庭枢纽远程访问基础 | 登录、设备授权、DNS 策略手工恢复 |
| Syncthing | 点对点同步 | 开源，适合家庭设备同步 | 设备 ID、共享目录、忽略规则手工恢复 |
| Kopia / restic / rclone | 备份和远端同步 | 支持长期备份策略 | 仓库密码、repo 地址、keyfile 不入库 |
| Caddy | 反向代理和本地 HTTPS | 配置简洁，适合家庭服务入口 | Caddyfile、证书、内网域名手工恢复 |
| sing-box / Mihomo | 代理核心 | 本机已有 Homebrew sing-box 使用痕迹，保留双核心候选 | 订阅、节点、secret、运行态不入库；避免多个 TUN 常驻 |
| smartmontools / nmap / iperf3 / mtr / wakeonlan | 设备健康和网络诊断 | 家庭枢纽常用排障工具 | 扫描目标、拓扑和日志不入库 |
| WireGuard tools / Mosquitto | 网络和 MQTT 基础能力 | 家庭自动化/隧道候选 | key、peer、broker 密码手工恢复 |
| RustDesk | 远程协助 | 开源远控，适合备用入口 | 设备码、无人值守密码和自建 server 配置不入库 |
| KeepingYouAwake | 防睡眠 | Mac mini 长期开机场景实用 | 是否常驻按设备电源策略决定 |

## 其他显式层

| Profile | 应用 | 策略 |
|---|---|---|
| `communication` | Telegram, WeChat, WeChat Work, Zoom, Discord, Windows App | 账号绑定强，不进默认层 |
| `dev-extra` | Zed, Beekeeper Studio, Bruno, DB Browser, draw.io, SourceGit, Tabby | GUI 开发工具，数据库连接和账号手工恢复 |
| `network-toolkit` | LuLu, Proxyman | LuLu 开源防火墙值得保留；Proxyman 证书和抓包授权手工处理 |
| `containers` | OrbStack, Docker CLI, Compose, Buildx, lazydocker | Mac 侧首选 OrbStack；镜像、volume、VM 状态不入库 |
| `local-ai` | Cherry Studio, ChatWise, Ollama, LM Studio, Jan | 客户端可恢复，模型、API keys 和对话历史不入库 |
| `mobile-dev` | Android Studio | SDK、模拟器、账号和项目缓存手工恢复 |

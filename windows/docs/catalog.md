# 应用目录

本文件是当前个人应用目录的总览。`windows/manifests/` 是 Windows 可自动恢复部分；每个软件的用途、保留理由和恢复边界见 `apps.md`，WSL 开发环境见 `../../wsl/docs/wsl.md` 和 `../../wsl/docs/tools.md`，手工、敏感和非包管理器来源见 `sources.md` 和 `manual-boundaries.md`。

## 默认层

| Profile | 自动安装 | 定位 | 应用 |
|---|---|---|---|
| `core` | 是 | Windows 基础环境 | Chrome, NanaZip, PowerShell, Windows Terminal, Git, PowerToys, Everything, UniGetUI, LocalSend, Bitwarden |
| `agentic-dev` | 是 | Agentic coding Windows 入口 | VS Code, Codex, Claude, GitHub CLI, WSL, Python Install Manager |

`default` 等同于 `core + agentic-dev`。AI 编程工具主线只保留 Codex 和 Claude；Copilot 不进入个人恢复目录。

Docker、Node.js、Kubernetes CLI 和主力开发 CLI 优先放在 WSL。Python Install Manager 只作为 Windows 原生 Python 入口，不作为主项目开发 Python 来源。播放器默认跟随 `daily` profile 中的 PotPlayer。

## 显式角色层

这些 profile 必须手工指定，不进入默认层。

| Profile | 自动安装 | 定位 | 应用 |
|---|---|---|---|
| `daily` | 是 | 主力个人设备日常工具 | Obsidian, Typora, PixPin, SumatraPDF, MediaInfo, PotPlayer |
| `daily-extra` | 是 | 日常增强候选 | Ditto, QuickLook, ShareX, PDFArranger, Okular, ImageGlass, Pandoc |
| `backup` | 是，配置手工 | 备份客户端 | Kopia UI |
| `backup-cli` | 是，仓库配置手工 | Windows 侧备份和远端同步 CLI | restic, rclone |
| `network` | 是，账号手工 | 可信网络和远程文件 | Tailscale, WinSCP |
| `automation` | 是，配置另备 | 自动化和文本扩展 | AutoHotkey, Espanso |
| `communication` | 是，账号手工 | 通讯、会议和输入法 | WeChat, WeType, WeCom, Tencent Meeting, Telegram |
| `dev-extra` | 是 | Windows GUI 开发增强 | DBeaver, DB Browser for SQLite, SourceGit, Bruno, DevToys, WinMerge, draw.io |
| `k8s-toolkit` | 是，集群凭据手工 | Windows 侧 Kubernetes / K3s 备用工具链 | kubectl, Helm, k9s, kubectx, kubens, stern, ORAS |
| `maintenance` | 是，按需使用 | 系统维护、卸载、硬件和磁盘诊断 | BCUninstaller, Sysinternals Suite, WizTree, CrystalDiskInfo, CrystalDiskMark, HWiNFO |
| `desktop-enhance` | 是 | 桌面增强 | Twinkle Tray, EarTrumpet |
| `media` | 是 | 基础媒体转换 | HandBrake, File Converter |
| `media-toolkit` | 是 | 媒体工具链 | FFmpeg, yt-dlp, MKVToolNix, Subtitle Edit, Czkawka |
| `gaming` | 是 | 游戏启动器和库管理 | Steam, Epic Games Launcher, Playnite |
| `sync-storage` | 是，数据目录手工 | 同步和加密存储 | Syncthing, Cryptomator |
| `security-toolkit` | 是，配置和证书手工 | 加密、网络和安全调试工具 | VeraCrypt, WireGuard, Wireshark, Nmap |
| `creative` | 是，大体积数据手工 | 创作和建模工具 | Shotcut, Blender, FreeCAD |
| `local-ai` | 是，数据手工 | Windows 侧本地模型工具 | Ollama, Jan, LM Studio |
| `proxy-core` | 是，配置手工 | 代理核心二进制 | Mihomo, sing-box, WinSW |

## 工具箱层

| Profile | 定位 | 说明 |
|---|---|---|
| `optional-oss` | 开源候选工具箱 | 不建议整层安装，只保留少量候选工具 |
| `scoop-cli` | Windows CLI 备用层 | 通过 `-WithScoop` 安装；主力 CLI 优先放 WSL |

`optional-oss` 当前包含：KeePassXC, Flameshot, VSCodium, Meld。

`scoop-cli` 当前包含：`ripgrep`, `fd`, `fzf`, `jq`, `yq`, `bat`, `delta`, `lazygit`, `zoxide`, `starship`, `uv`, `pnpm`, `neovim`, `just`。这些工具在 Windows 侧只作为备用；主力开发环境优先使用 WSL 版本。

## WSL 层

WSL 不通过 winget manifest 管理。相关文件位于 `../../wsl/`：

- `../../wsl/bootstrap.sh`：WSL 初始化脚本；
- `../../wsl/packages/apt-base.txt`：基础 apt 包；
- `../../wsl/packages/cli.txt`：主力开发 CLI 工具链；
- `../../wsl/packages/k8s.txt`：Kubernetes / K3s 工具链；
- `../../wsl/packages/docker.txt`：Docker Engine 工具链；
- `../../wsl/docs/wsl.md`：WSL 使用说明；
- `../../wsl/docs/tools.md`：WSL 工具用途、常用方式和恢复边界；
- `../../wsl/docs/wsl-boundaries.md`：WSL 敏感配置和数据边界。

## `all` 边界

`all` 只包含：

- `core`
- `agentic-dev`
- `daily`
- `media`
- `gaming`

`all` 不包含：

- `daily-extra`
- `backup`
- `backup-cli`
- `network`
- `automation`
- `communication`
- `dev-extra`
- `k8s-toolkit`
- `maintenance`
- `desktop-enhance`
- `media-toolkit`
- `sync-storage`
- `security-toolkit`
- `creative`
- `local-ai`
- `proxy-core`
- `optional-oss`

这些 profile 都代表明确设备角色、账号状态、敏感配置边界、大体积工具或按需维护场景，必须显式安装。

# 应用目录

本文件是当前个人应用目录的总览。`windows/manifests/` 是可自动恢复部分；手工、敏感和非包管理器来源见 `sources.md` 和 `manual-boundaries.md`。

## 默认层

| Profile | 自动安装 | 定位 | 应用 |
|---|---|---|---|
| `core` | 是 | Windows 基础环境 | Chrome, NanaZip, PowerShell, Windows Terminal, Git, PowerToys, Everything, BCUninstaller, UniGetUI, LocalSend, Bitwarden |
| `agentic-dev` | 是 | Agentic coding 主环境 | VS Code, Codex, Claude, GitHub CLI, WSL, Docker Desktop, Python Install Manager, Node.js LTS |

`default` 等同于 `core + agentic-dev`。

Python 通过 Python Install Manager 管理，不在本仓库锁定某个 CPython 小版本。播放器默认跟随 `daily` profile 中的 PotPlayer。

## 显式角色层

这些 profile 必须手工指定，不进入默认层。

| Profile | 自动安装 | 定位 | 应用 |
|---|---|---|---|
| `daily` | 是 | 主力个人设备日常工具 | Obsidian, Typora, PixPin, SumatraPDF, MediaInfo, PotPlayer |
| `backup` | 是，配置手工 | 备份客户端 | Kopia UI |
| `network` | 是，账号手工 | 可信网络和远程文件 | Tailscale, WinSCP |
| `automation` | 是，配置另备 | 自动化和文本扩展 | AutoHotkey, Espanso |
| `communication` | 是，账号手工 | 通讯、会议和输入法 | WeChat, WeType, WeCom, Tencent Meeting, Telegram |
| `dev-extra` | 是 | 数据库和开发增强 | DBeaver, DB Browser for SQLite, mise, SourceGit |
| `desktop-enhance` | 是 | 桌面增强 | Twinkle Tray, EarTrumpet |
| `media` | 是 | 基础媒体转换 | HandBrake, File Converter |
| `media-toolkit` | 是 | 媒体工具链 | FFmpeg, yt-dlp, MKVToolNix, Subtitle Edit, Czkawka |
| `gaming` | 是 | 游戏启动器和库管理 | Steam, Epic Games Launcher, Playnite |
| `local-ai` | 是，数据手工 | 本地模型工具 | Ollama, Jan, LM Studio |
| `proxy-core` | 是，配置手工 | 代理核心二进制 | Mihomo, sing-box, WinSW |

## 工具箱层

| Profile | 定位 | 说明 |
|---|---|---|
| `optional-oss` | 开源候选工具箱 | 不建议整层安装，只按需挑选 |
| `scoop-cli` | CLI 补充层 | 通过 `-WithScoop` 安装 |

`scoop-cli` 当前包含：`ripgrep`, `fd`, `fzf`, `jq`, `yq`, `bat`, `delta`, `lazygit`, `zoxide`, `starship`, `uv`, `pnpm`, `neovim`, `just`, `hyperfine`, `tokei`, `bottom`, `duf`, `dust`。

## `all` 边界

`all` 只包含：

- `core`
- `agentic-dev`
- `daily`
- `media`
- `gaming`
- `optional-oss`

`all` 不包含：

- `backup`
- `network`
- `automation`
- `communication`
- `dev-extra`
- `desktop-enhance`
- `media-toolkit`
- `local-ai`
- `proxy-core`

这些 profile 都代表明确设备角色、账号状态或敏感配置边界，必须显式安装。

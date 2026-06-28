# macOS 应用目录

本文件是 macOS 恢复面的总览。`mac/manifests/Brewfile-*` 是 Homebrew 自动恢复清单；`mac/packages/` 是 mise 和服务启用参考清单；`mac/config/` 是脱敏工具配置模板。真实账号、授权、代理节点、备份密钥、家庭服务运行态和 App Store 登录状态不进入仓库。

当前 mac 侧按 **Mac mini 长期开机、家庭核心管理枢纽** 设计：默认层仍保持小；家庭服务、容器、本地 AI、移动开发和网络调试都必须显式安装。

## 默认层

| Profile | 自动安装 | 定位 | 应用 |
|---|---|---|---|
| `core` | 是 | macOS 基础环境 | Firefox, Chrome, Bitwarden, Keka, LocalSend, Maccy, Itsycal, Ice, Stats, Raycast, JetBrains Mono Nerd Font, Git/jq/rg/fd/fzf/bat/eza/btop |
| `agentic-dev` | 是 | Agentic coding 与终端入口 | VS Code, iTerm2, ChatGPT, Claude, mise, gh, just, direnv, zoxide, starship, delta, lazygit, neovim, shellcheck, shfmt, yq |

`default` 等同于 `core + agentic-dev`。Codex App 当前不走 Homebrew；已安装时保留，但恢复路径写在 `manual-boundaries.md`。

## 显式角色层

这些 profile 需要手工指定，不进入默认层。

| Profile | 自动安装 | 定位 | 应用 |
|---|---|---|---|
| `daily` | 是 | 日常写作、阅读、媒体和下载 | Obsidian, Logseq, MarkEdit, Typora, Skim, IINA, Folo, Motrix |
| `desktop-enhance` | 是，权限手工 | Mac 桌面、显示器、鼠标和效率增强 | Rectangle, AltTab, BetterDisplay, LinearMouse, Mos, OnlySwitch, PixPin, PopClip |
| `communication` | 是，账号手工 | 通讯、会议和远程桌面入口 | Telegram, WeChat, WeChat Work, Zoom, Discord, Windows App |
| `dev-extra` | 是，账号/数据库连接手工 | GUI 开发增强 | Zed, Beekeeper Studio, Bruno, DB Browser for SQLite, draw.io, SourceGit, Tabby |
| `network-toolkit` | 是，证书/规则手工 | 网络、安全和 HTTP 调试 | LuLu, Proxyman |
| `media` | 是 | 媒体转换和处理 | FFmpeg, yt-dlp, ImageMagick, MKVToolNix, HandBrake |
| `creative` | 是，大体积数据手工 | 创作和建模工具 | Shotcut, Blender, FreeCAD |
| `maintenance` | 是，按需使用 | 应用清理和更新检查 | Pearcleaner, Latest |
| `home-hub` | 是，服务配置手工 | Mac mini 家庭枢纽 | restic, rclone, Kopia/KopiaUI, Syncthing, Caddy, sing-box, Mihomo, smartmontools, nmap, iperf3, mtr, wakeonlan, WireGuard tools, Mosquitto, Tailscale, RustDesk, KeepingYouAwake |
| `containers` | 是，运行态手工 | macOS 容器运行时 | OrbStack, Docker CLI, Docker Compose, Buildx, lazydocker |
| `local-ai` | 是，模型和 API keys 手工 | 本地模型与多模型客户端 | Cherry Studio, ChatWise, Ollama, LM Studio, Jan |
| `mobile-dev` | 是，SDK/模拟器手工 | Android 开发 | Android Studio |
| `gaming` | 是，账号和游戏数据手工 | 游戏入口 | Steam |

## mise 工具链

`mac/packages/mise-cli.txt` 管理主力开发运行时：

- `node@lts`
- `python@latest`
- `uv@latest`
- `pnpm@latest`

`mac/packages/mise-k8s.txt` 管理 Kubernetes 工具：`kubectl`、`helm`、`k9s`、`kubectx`、`kubens`、`stern`、`oras`。这些工具不写入 Brewfile，避免和 Homebrew 版本来源混用。

## 家庭枢纽服务

`mac/packages/services-home-hub.txt` 只记录可考虑 `brew services` 管理的服务和建议 scope，不自动启用。服务配置、证书、订阅、设备 ID 和运行态见 `home-hub.md`。

## 配置层

`mac/config/` 是 opt-in 配置层，不是 Homebrew profile。使用：

```bash
./mac/configure.sh --all --plan
./mac/configure.sh --all
```

配置层包括 zsh、Git、VS Code、starship、tmux、bat、lazygit 和一组非敏感 macOS defaults。详见 `config.md`。

## 已安装但不自动恢复

本机已安装的一些小众/新工具只记录边界，不放进自动层：

- Bob：Homebrew cask 已弃用并转向 Mac App Store；保留为翻译工具候选，自动恢复暂缓。
- Shadowrocket、APTV、Infuse、SenPlayer、MediaCenter、iMenu、小米互联服务：App Store/订阅/账号/区域绑定强，手工恢复。
- Sniffnet：开源网络流量观察工具，但当前 Homebrew cask 不可用；记录为手工候选。
- AnyGo、Otty、Hermes：来源、维护状态或授权边界不适合作为恢复默认项。
- IntelliJ IDEA：商业授权和插件状态手工恢复；需要时再补独立 profile。
- Steam 游戏本体和存档：跟随 Steam/云存档，不入库。

## `all` 边界

`all` 只包含：

- `core`
- `agentic-dev`
- `daily`
- `desktop-enhance`
- `home-hub`
- `media`

`all` 不包含：

- `communication`
- `dev-extra`
- `network-toolkit`
- `creative`
- `maintenance`
- `containers`
- `local-ai`
- `mobile-dev`
- `gaming`

这些 profile 代表账号登录、证书/代理规则、重型运行时、大体积数据、商业授权或按需维护场景，必须显式安装。


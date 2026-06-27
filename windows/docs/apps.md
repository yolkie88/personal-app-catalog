# 应用说明

本文件记录每个软件或工具的用途、保留理由和恢复边界。它不是百科介绍，重点是帮助判断：为什么它在这个 profile、什么时候应该安装、哪些配置不能依赖自动恢复。

## 默认层

### `core`

| 工具 | 用途 | 保留理由 | 恢复边界 |
|---|---|---|---|
| Chrome | 主浏览器 | 兼容性强，适合作为新设备默认网页入口 | 账号、扩展和书签依赖浏览器同步或手工恢复 |
| NanaZip | 压缩解压 | 现代 Windows 集成较好，替代传统压缩工具 | 无明显边界，按需调整关联格式 |
| PowerShell | Shell 和脚本环境 | Windows 自动化和恢复脚本基础 | Profile、模块和执行策略按设备处理 |
| Windows Terminal | 终端入口 | 统一 PowerShell、WSL 和其他命令行入口 | 配色、字体、profile 配置可另做模板 |
| Git | 版本控制 | 开发、配置管理和仓库恢复基础 | 用户名、邮箱、签名、SSH/GPG 配置手工恢复 |
| PowerToys | Windows 增强工具箱 | 窗口管理、启动器、键盘映射等高频增强 | 各模块开关和快捷键按设备调整 |
| Everything | 文件搜索 | Windows 文件名搜索效率高，适合主力机 | 索引范围和权限按设备调整 |
| LocalSend | 局域网传输 | 跨 Windows、macOS、手机传文件方便 | 设备发现和局域网权限按网络环境处理 |
| Bitwarden | 密码管理 | 新设备恢复入口，优先级高 | 只安装客户端，账号、主密码和二次验证手工处理 |

### `agentic-dev`

| 工具 | 用途 | 保留理由 | 恢复边界 |
|---|---|---|---|
| VS Code | 编辑器和轻量 IDE | Windows 侧 UI 入口，配合 WSL 做主开发环境 | 扩展、设置、登录状态可同步或手工恢复 |
| Codex | AI 编程工具 | 当前主力 agentic coding 工具之一 | 登录、API、模型和项目权限按设备处理 |
| Claude | AI 编程工具 | 当前主力 agentic coding 工具之一 | 登录、权限、项目上下文和本地配置手工处理 |
| WSL | Linux 子系统 | 主开发、运维、CLI 和 Docker 执行环境 | 发行版、home 目录、密钥和 Linux 配置另行恢复 |
| Python Install Manager | Windows 原生 Python 入口 | 只服务少量 Windows 脚本或工具需求 | 主项目 Python 优先放 WSL，Windows 包缓存不入库 |

## WSL 主力工具链

WSL 不是 Windows winget profile，但它是主开发执行环境。相关清单见 `../../wsl/packages/`，初始化脚本见 `../../wsl/bootstrap.sh`。

| 工具 | 用途 | 保留理由 | 恢复边界 |
|---|---|---|---|
| Docker Engine | 容器运行时 | Docker 放 WSL，避免 Windows 和 Linux 两边维护两套主运行时 | registry 登录、镜像、volume 和 Compose 数据不入库 |
| Node.js LTS | Node.js 运行时 | 前端、脚本和 AI 工具链优先在 WSL 执行 | 全局包和缓存按 WSL 环境恢复 |
| Python | Python 运行时 | 主项目 Python 优先在 WSL 内管理 | 虚拟环境、包缓存和项目数据不入库 |
| mise | 多语言运行时和任务管理 | 统一管理 WSL 内 Node、Python、CLI 和项目任务 | 全局配置可模板化，项目配置跟随项目仓库 |
| uv | Python 包和项目工具 | 快速、现代的 Python 工具链 | 项目环境和缓存不入库 |
| pnpm | Node 包管理 | 前端和工具链常用 | store 路径和项目依赖按项目管理 |
| gh | GitHub CLI | PR/issue/仓库/`gh auth`；放 WSL 贴近代码与 git（已从 Windows agentic-dev 移入） | `gh auth` 登录状态和 token 不入库 |
| Claude Code / Codex CLI | 终端 agentic 编码 | 跑在代码、git、工具链旁边；官方原生安装器自更新 | 登录、权限、项目上下文手工恢复，不入库 |
| kubectl | Kubernetes CLI | K8s/K3s 主力操作工具放 WSL 更贴近服务器环境 | kubeconfig 和集群凭据手工恢复 |
| Helm | Kubernetes 包管理 | Chart 安装和升级优先在 WSL 执行 | repo 配置和 values 文件按项目处理 |
| k9s | K8s 终端 UI | 集群资源观察和操作效率高 | 依赖 kubeconfig，主题和快捷键按设备处理 |
| kubectx / kubens | context / namespace 切换 | 多集群、多 namespace 操作更顺手 | 依赖 kubeconfig，不单独保存凭据 |
| stern | Pod 日志聚合 | 多 Pod 日志查看和排查方便 | 依赖集群权限，过滤规则按场景使用 |
| ORAS | OCI artifact 工具 | 处理 OCI Registry、Chart、镜像外 artifact 方便 | registry 登录状态和凭据手工处理 |

## 日常和桌面

### `daily`

| 工具 | 用途 | 保留理由 | 恢复边界 |
|---|---|---|---|
| Obsidian | 知识库 | 个人文档和长期知识管理入口 | Vault、同步方式、插件和主题按数据目录恢复 |
| Typora | Markdown 编辑 | 写作体验好，适合轻量文档编辑 | 授权和主题配置手工处理 |
| PixPin | 截图和标注 | 中文 Windows 环境下体验好，适合日常截图 | 快捷键和本地配置按设备处理 |
| SumatraPDF | PDF 阅读 | 轻量、启动快，适合基础阅读 | 关联格式和阅读历史按设备处理 |
| MediaInfo | 媒体信息查看 | 视频和音频文件排查常用 | 无明显边界 |
| PotPlayer | 播放器 | Windows 上媒体播放兼容性强 | 解码、皮肤、播放记录和关联格式按设备处理 |

### `daily-extra`

| 工具 | 用途 | 保留理由 | 恢复边界 |
|---|---|---|---|
| Ditto | 剪贴板增强 | 多条剪贴板历史提升日常效率 | 常驻后台，历史数据不建议同步入库 |
| QuickLook | 文件快速预览 | 类 macOS 空格预览体验，提升文件浏览效率 | 插件和关联行为按设备调整 |
| ShareX | 截图和自动化分享 | 功能强，适合高级截图、录屏和工作流 | 上传目标、token、历史记录不入库 |
| PDFArranger | PDF 页面整理 | 合并、拆分、调整 PDF 页面的轻量工具 | 无明显边界 |
| Okular | 文档阅读 | 支持多格式文档和批注，作为 SumatraPDF 补充 | 批注和最近文件按设备处理 |
| ImageGlass | 图片查看 | 轻量图片浏览，替代系统默认查看器 | 关联格式和主题按设备处理 |
| Pandoc | 文档格式转换 | Markdown/docx/HTML/PDF 等文档互转的命令行工具 | LaTeX/PDF 引擎按需另装 |

### `desktop-enhance`

| 工具 | 用途 | 保留理由 | 恢复边界 |
|---|---|---|---|
| Twinkle Tray | 显示器亮度控制 | 多显示器亮度调节方便 | 显示器能力和快捷键按设备处理 |
| EarTrumpet | 音量管理 | 更细粒度的应用音量控制 | 输出设备和默认音频路由按设备处理 |

## 开发和运维

### `dev-extra`

| 工具 | 用途 | 保留理由 | 恢复边界 |
|---|---|---|---|
| DBeaver | 数据库客户端 | 覆盖 PostgreSQL、SQLite 等多数据库场景 | 连接配置、密码和驱动缓存不入库 |
| DB Browser for SQLite | SQLite GUI | 轻量查看和编辑 SQLite 文件 | 无明显边界，数据库文件不归本仓库管理 |
| SourceGit | Git GUI | 轻量 Git 图形客户端，补充 CLI 和 VS Code | 账号、密钥和本地仓库路径按设备处理 |
| Bruno | API 调试 | local-first、Git 友好，适合接口集合和 AI 协作 | 环境变量、token 和真实地址需脱敏 |
| DevToys | 开发小工具 | JSON、编码、哈希、时间戳等高频处理 | 无明显边界 |
| WinMerge | 文件和目录对比 | Windows 上成熟的 diff/merge 工具 | 外部工具集成按设备配置 |
| draw.io | 图形绘制 | 架构图、流程图、本地绘图常用 | 文件存储跟随项目或知识库 |

### `k8s-toolkit`

| 工具 | 用途 | 保留理由 | 恢复边界 |
|---|---|---|---|
| kubectl | Kubernetes CLI | Windows 侧备用 K8s/K3s 操作工具 | 主力 kubeconfig 放 WSL，Windows 凭据手工处理 |
| Helm | Kubernetes 包管理 | Windows 侧备用 Chart 操作工具 | repo 配置和 values 文件按项目处理 |
| k9s | K8s 终端 UI | Windows 侧备用集群资源观察工具 | kubeconfig、快捷键和主题按设备处理 |
| kubectx | kube context 切换 | Windows 侧备用 context 切换工具 | 依赖 kubeconfig，不单独保存凭据 |
| kubens | namespace 切换 | Windows 侧备用 namespace 切换工具 | 依赖 kubeconfig，不单独保存凭据 |
| stern | Pod 日志聚合 | Windows 侧备用日志查看工具 | 依赖集群权限，过滤规则按场景使用 |
| ORAS | OCI artifact 工具 | Windows 侧备用 OCI artifact 工具 | registry 登录状态和凭据手工处理 |

### `scoop-cli`

| 工具 | 用途 | 保留理由 | 恢复边界 |
|---|---|---|---|
| ripgrep | 文本搜索 | Windows 侧备用搜索工具，主力放 WSL | 无明显边界 |
| fd | 文件查找 | Windows 侧备用查找工具，主力放 WSL | 无明显边界 |
| fzf | 模糊选择 | Windows 侧备用终端交互工具，主力放 WSL | Shell 集成按设备配置 |
| jq | JSON 处理 | Windows 侧备用 JSON 处理工具，主力放 WSL | 无明显边界 |
| yq | YAML 处理 | Windows 侧备用 YAML 处理工具，主力放 WSL | 无明显边界 |
| bat | 文件查看 | Windows 侧备用文件查看工具，主力放 WSL | 主题按设备处理 |
| delta | Git diff 增强 | Windows 侧备用 diff 工具，主力放 WSL | Git 集成按设备处理 |
| lazygit | Git TUI | Windows 侧备用 Git TUI，主力放 WSL | 账号和签名仍由 Git 配置决定 |
| zoxide | 目录跳转 | Windows 侧备用目录跳转工具，主力放 WSL | 历史数据库按设备生成 |
| starship | Shell prompt | Windows 侧备用提示符，主力放 WSL | 字体和配置可模板化 |
| uv | Python 包和项目工具 | Windows 侧备用，主项目优先 WSL | 项目环境和缓存不入库 |
| pnpm | Node 包管理 | Windows 侧备用，主项目优先 WSL | store 路径和项目依赖按项目管理 |
| neovim | 终端编辑器 | Windows 侧备用，主力放 WSL | 配置可独立维护，不建议塞入本仓库 |
| just | 命令任务入口 | Windows 侧备用任务工具，主力放 WSL | justfile 跟随项目仓库 |

## 系统维护

### `maintenance`

`maintenance` 的其余条目（BCUninstaller、Sysinternals Suite、WizTree、CrystalDiskInfo、CrystalDiskMark、HWiNFO）是按需诊断/卸载工具，用途直观，归类见 `catalog.md`。这里只记需要判断的一项：

| 工具 | 用途 | 保留理由 | 恢复边界 |
|---|---|---|---|
| UniGetUI | 包管理 GUI | 仅作发现/查 ID、浏览 winget/Scoop 来源的图形工具；已从默认层 `core` 降到按需安装的 `maintenance` | 不作为恢复事实来源（manifest 才是）。关闭其后台自动更新，更新统一交给 `update.ps1 -Exclude` + 计划任务，避免和 winget pin 两套清单冲突 |

## 网络、备份和同步

### `network`

| 工具 | 用途 | 保留理由 | 恢复边界 |
|---|---|---|---|
| Tailscale | 可信组网 | 个人设备、服务器和远程访问基础 | 登录、设备授权和 tailnet 策略手工处理 |
| WinSCP | 远程文件传输 | SFTP/SCP/FTP 图形客户端，适合服务器文件操作 | 站点密码和密钥不入库 |

### `backup`

| 工具 | 用途 | 保留理由 | 恢复边界 |
|---|---|---|---|
| Kopia UI | 备份客户端 | 图形化备份和恢复，适合桌面设备 | 仓库地址、密码、keyfile 和策略手工恢复 |

### `backup-cli`

| 工具 | 用途 | 保留理由 | 恢复边界 |
|---|---|---|---|
| restic | 备份 CLI | Windows 侧备份 CLI；WSL home 也可用 WSL 侧 restic | 仓库地址、密码和恢复密钥不入库 |
| rclone | 远端同步 CLI | Windows 侧远端同步 CLI；主力脚本可放 WSL | remote 配置和凭据手工恢复 |

### `sync-storage`

| 工具 | 用途 | 保留理由 | 恢复边界 |
|---|---|---|---|
| Syncthing | 点对点同步 | 多设备文件同步，不依赖中心云服务 | 设备 ID、共享目录和同步策略手工恢复 |
| Cryptomator | 加密保险库 | 云盘或同步目录上的文件级加密 | vault 密钥和恢复信息不入库 |

## 自动化、通讯和媒体

### `automation`

| 工具 | 用途 | 保留理由 | 恢复边界 |
|---|---|---|---|
| AutoHotkey | Windows 自动化 | 快捷键、窗口操作和小脚本能力强 | 脚本可单独维护，涉及路径和账号的配置脱敏 |
| Espanso | 文本扩展 | 跨应用短语和模板输入 | 个人短语和敏感文本不直接入库 |

### `communication`

| 工具 | 用途 | 保留理由 | 恢复边界 |
|---|---|---|---|
| WeChat | 通讯 | 高频个人通讯 | 账号登录、聊天记录和文件按官方机制恢复 |
| WeType | 输入法 | 中文输入方案 | 词库和账号同步按设备处理 |
| WeCom | 企业微信 | 工作通讯 | 企业账号和本地缓存手工处理 |
| Tencent Meeting | 会议 | 国内会议常用 | 账号和会议历史手工处理 |
| Telegram Desktop | 通讯 | 跨平台通讯和频道阅读 | 登录状态和本地缓存手工处理 |

### `media`

| 工具 | 用途 | 保留理由 | 恢复边界 |
|---|---|---|---|
| HandBrake | 视频转码 | 常用视频压缩和格式转换工具 | 预设可另行导出，源文件不归本仓库管理 |
| File Converter | 右键格式转换 | 日常图片、音频、视频转换方便 | 右键菜单和转换参数按设备处理 |

### `media-toolkit`

| 工具 | 用途 | 保留理由 | 恢复边界 |
|---|---|---|---|
| FFmpeg | 媒体处理 CLI | 音视频处理底层工具，脚本常用 | 编码参数和脚本按项目维护 |
| yt-dlp | 媒体下载 CLI | 下载和归档公开媒体内容 | cookies、账号信息和下载目录不入库 |
| MKVToolNix | MKV 工具 | 封装、拆分和调整 MKV 文件 | 文件和预设按任务处理 |
| Subtitle Edit | 字幕编辑 | 字幕修正、同步和格式转换 | 字幕文件按项目或媒体目录管理 |
| Czkawka | 重复文件清理 | 查找重复、空目录和大文件 | 删除操作需手工确认，不进入默认层 |

## 安全、代理、本地 AI 和创作

### `security-toolkit`

| 工具 | 用途 | 保留理由 | 恢复边界 |
|---|---|---|---|
| VeraCrypt | 加密容器 | 本地加密盘和敏感数据容器 | 密码、keyfile 和容器文件不入库 |
| WireGuard | VPN 客户端 | 轻量 VPN 和网络调试 | 配置文件和密钥手工恢复 |
| Wireshark | 抓包分析 | 网络排障和协议分析 | 驱动、证书和抓包文件按场景处理 |
| Nmap | 网络扫描 | 自有网络资产探测和排障 | 仅在授权网络使用，扫描目标不写入目录 |

### `proxy-core`

| 工具 | 用途 | 保留理由 | 恢复边界 |
|---|---|---|---|
| Mihomo | 代理核心 | 本项目首选的轻量主核心，配合 Web UI + 系统代理 | 订阅、节点、secret 和真实配置不入库 |
| WinSW | Windows 服务封装 | 将 mihomo 封装为 Windows 服务，开机自启 | 服务路径、账号和权限按设备处理 |

> sing-box（`SagerNet.sing-box`）不再随 `proxy-core` 默认安装。它作为可选备用核心：只有当某些场景确实需要它的 TUN / 路由能力时，再手工 `winget install SagerNet.sing-box`。这样可贴近“mihomo 单核心轻量”的目标，避免两个 TUN 核心同时常驻。

> Mihomo 和 WinSW 是 winget 的 archive / portable 包：只解压一个 exe 到 `%LOCALAPPDATA%\Microsoft\WinGet\Packages\…` 的哈希目录里，无安装器、无 PATH shim、不好找。装完用 `.\windows\publish-tools.ps1` 把它们落到 `C:\Tools\mihomo\`（`mihomo.exe` / `mihomo-service.exe`）这种固定路径，给启动器和 WinSW 服务一个稳定引用。winget 仍是版本来源，`winget upgrade` 后重跑一次 publish 即可。详见 `windows/docs/proxy.md`。

### `local-ai`

| 工具 | 用途 | 保留理由 | 恢复边界 |
|---|---|---|---|
| Ollama | 本地模型运行 | Windows 侧本地 LLM 体验和测试方便 | 模型数据体积大，不进入 Git |
| Jan | 本地 AI 客户端 | 图形化本地模型和聊天体验 | 模型、会话和配置按设备处理 |
| LM Studio | 本地 AI 客户端 | 本地模型下载、运行和测试方便 | 模型数据和缓存不进入 Git |

### `creative`

| 工具 | 用途 | 保留理由 | 恢复边界 |
|---|---|---|---|
| Shotcut | 视频剪辑 | 开源视频编辑工具，适合轻量剪辑 | 项目文件和素材不归本仓库管理 |
| Blender | 3D 创作 | 建模、渲染和 3D 资产处理 | 插件、素材库和项目文件按创作目录管理 |
| FreeCAD | CAD 建模 | 参数化建模和工程类设计 | 插件、模板和项目文件按创作目录管理 |

## 游戏和候选工具

### `gaming`

| 工具 | 用途 | 保留理由 | 恢复边界 |
|---|---|---|---|
| Steam | 游戏平台 | 主流游戏平台和库管理 | 账号、游戏本体、存档和 Mod 不入库 |
| Epic Games Launcher | 游戏平台 | Epic 游戏库入口 | 账号、游戏本体和存档不入库 |
| Playnite | 游戏库管理 | 统一管理多个游戏平台库 | 数据库、封面和插件按设备或备份恢复 |

### `optional-oss`

| 工具 | 用途 | 保留理由 | 恢复边界 |
|---|---|---|---|
| KeePassXC | 本地密码库 | 作为 Bitwarden 之外的本地密码库候选 | 密码库、keyfile 和主密码不入库 |
| Flameshot | 截图工具 | 开源截图候选，适合替代或补充 PixPin/ShareX | 快捷键和配置按设备处理 |
| VSCodium | 编辑器候选 | VS Code 的非微软构建候选 | 扩展和设置需独立恢复 |
| Meld | 文件对比 | 跨平台 diff/merge 工具候选 | 外部工具集成按设备处理 |

# personal-app-catalog

个人应用清单中心，附带 Windows 和 WSL 恢复脚本。

这个仓库维护的是“长期认可、愿意跨设备恢复的应用目录”，不是某台电脑的软件盘点。能自动安装的 Windows 内容放在 `windows/manifests/`，WSL 开发环境放在 `wsl/`，不能或不应该自动恢复的内容写入文档的手工边界。

## 快速使用

先做 Windows 侧结构校验、WSL 发行版检查和安装预览：

```powershell
cd <repo-path>
Set-ExecutionPolicy -Scope Process Bypass
.\windows\validate.ps1
.\windows\wsl-distro.ps1 -Plan
.\windows\bootstrap.ps1 -Plan -Report
```

确认后安装默认层：

```powershell
.\windows\bootstrap.ps1 -Report
```

默认层由 `bootstrap.ps1` 解析为 `core + agentic-dev`，具体安装项以 `windows/manifests/` 下对应 manifest 为准。`winget-*.json` 走 winget 源，`msstore-*.txt` 走 Microsoft Store 源。Docker、Node.js、Kubernetes CLI 和主力开发 CLI 由 WSL 侧清单管理。

WSL 侧需要先有 Linux 发行版。本项目默认发行版基线是 `Ubuntu-26.04`，可通过参数改成其他发行版：

```powershell
.\windows\wsl-distro.ps1 -Install -Distro Ubuntu-26.04 -SetDefault
```

首次安装后需要启动该发行版一次，创建 Linux 用户。之后进入 WSL，在仓库目录下执行：

```bash
bash wsl/validate.sh
./wsl/bootstrap.sh --base --cli --k8s --plan
./wsl/bootstrap.sh --base --cli --k8s
```

Docker Engine 安装到 WSL：

```bash
./wsl/bootstrap.sh --docker
```

常用显式 Windows profile：

```powershell
.\windows\bootstrap.ps1 -Profile daily -Report
.\windows\bootstrap.ps1 -Profile daily-extra -Report
.\windows\bootstrap.ps1 -Profile backup -Report
.\windows\bootstrap.ps1 -Profile backup-cli -Report
.\windows\bootstrap.ps1 -Profile network -Report
.\windows\bootstrap.ps1 -Profile automation -Report
.\windows\bootstrap.ps1 -Profile communication -Report
.\windows\bootstrap.ps1 -Profile dev-extra -Report
.\windows\bootstrap.ps1 -Profile k8s-toolkit -Report
.\windows\bootstrap.ps1 -Profile maintenance -Report
.\windows\bootstrap.ps1 -Profile desktop-enhance -Report
.\windows\bootstrap.ps1 -Profile media -Report
.\windows\bootstrap.ps1 -Profile media-toolkit -Report
.\windows\bootstrap.ps1 -Profile gaming -Report
.\windows\bootstrap.ps1 -Profile sync-storage -Report
.\windows\bootstrap.ps1 -Profile security-toolkit -Report
.\windows\bootstrap.ps1 -Profile creative -Report
.\windows\bootstrap.ps1 -Profile local-ai -Report
.\windows\bootstrap.ps1 -Profile proxy-core -Report
.\windows\bootstrap.ps1 -WithScoop -Report
```

组合安装前建议先预览：

```powershell
.\windows\bootstrap.ps1 -Profile daily,network,automation,dev-extra -WithScoop -Plan -Report
```

应用工具优化配置（PowerShell、Windows Terminal、Git 共享配置；覆盖前先备份）：

```powershell
.\windows\configure.ps1 -All -Plan
.\windows\configure.ps1 -All
```

WSL 侧应用工具优化配置（nvim、starship、tmux、bat、lazygit、git、bash 别名）：

```bash
./wsl/bootstrap.sh --config --plan
./wsl/bootstrap.sh --config
```

更新和快照（`-Exclude` 跳过 `windows/manifests/update-exclude.txt` 里的敏感包，`schedule-update.ps1` 注册定时自动更新）：

```powershell
.\windows\update.ps1
.\windows\update.ps1 -All -IncludeScoop
.\windows\update.ps1 -All -Exclude
.\windows\schedule-update.ps1 -Exclude -Plan
.\windows\export.ps1
```

## 文档

| 文档 | 用途 |
|---|---|
| `windows/docs/catalog.md` | 当前 Windows profile 和应用目录 |
| `windows/docs/apps.md` | 每个软件的用途、保留理由和恢复边界 |
| `windows/docs/sources.md` | 来源优先级和非 winget 记录方式 |
| `windows/docs/manual-boundaries.md` | 敏感、授权、硬件、代理、远控等手工边界 |
| `windows/docs/operations.md` | Windows 安装、更新、维护流程 |
| `windows/docs/recovery-playbook.md` | 新设备恢复顺序和人工边界 |
| `windows/docs/config.md` | Windows 工具配置层（PowerShell、Terminal、Git）和 `configure.ps1` |
| `wsl/docs/wsl.md` | WSL-first 开发环境说明 |
| `wsl/docs/config.md` | WSL 工具配置层（nvim、starship、tmux、bat、lazygit、git、bash 别名） |
| `wsl/docs/tools.md` | WSL 工具用途、常用方式和恢复边界 |
| `wsl/docs/wsl-boundaries.md` | WSL 敏感配置和数据边界 |

## 目录规则

- 默认层保持小，只包含 `core` 和 `agentic-dev`。
- Windows 侧 `agentic-dev` 只保留入口工具；Docker、Node.js、K8s CLI 和主力 CLI 工具链优先放在 WSL。
- WSL 侧脚本必须在已安装的 Linux 发行版中执行，默认发行版基线为 `Ubuntu-26.04`。
- Python Install Manager 只用于 Windows 原生 Python 需求，主项目 Python 优先放在 WSL。
- `all` 不是完整个人环境，只是宽松集合；敏感、强设备角色、大体积或维护类 profile 必须显式安装。
- 同一应用只保留一个主来源。
- Store、GitHub Releases、官方安装器、语言包管理器、Docker/WSL 和便携应用可以进入目录，但要明确是否可自动恢复。
- 订阅、节点、授权码、设备码、私钥、token、备份密钥和模型数据不进入 Git。
- 提交前运行 `windows/validate.ps1` 和 `bash wsl/validate.sh`；恢复前优先使用 `-Plan -Report` 确认将要执行的安装。

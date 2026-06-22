# Windows + WSL 恢复手册

这份手册描述从一台新 Windows 设备恢复到可用个人工作环境的推荐顺序。它不是完整自动化脚本；账号、授权、私钥、订阅、设备绑定、备份密钥、WSL home、Docker volume 和 kubeconfig 仍按手工边界处理。

## 1. 系统前置

1. 完成 Windows 更新。
2. 从 Microsoft Store 更新 App Installer，确保 `winget` 可用。
3. 打开 PowerShell，执行：

```powershell
winget --version
```

如果 `winget` 不可用，先修复 App Installer，不要继续执行恢复脚本。

## 2. 获取仓库

如果 Git 尚未安装，可以先临时安装：

```powershell
winget install -e --id Git.Git --source winget --accept-package-agreements --accept-source-agreements
```

然后拉取仓库：

```powershell
git clone <repo-url>
cd personal-app-catalog
```

## 3. 先做 Windows 侧预览和校验

```powershell
.\windows\validate.ps1
.\windows\bootstrap.ps1 -Plan -Report
```

`-Plan` 只展示将安装的 profile 和包，不会安装软件。`-Report` 会在 `windows/reports/` 下生成本次预览报告，该目录不应提交。

## 4. 安装 Windows 默认层

默认层只包含 `core + agentic-dev`：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\windows\bootstrap.ps1 -Report
```

默认层完成后，优先确认这些内容：

- Chrome / Bitwarden 可用；
- Git / PowerShell / Windows Terminal 可用；
- VS Code / Codex / Claude 可用；
- WSL 可用。

默认层具体安装内容以 `windows/manifests/winget-core.json`、`windows/manifests/winget-agentic-dev.json` 和 `windows/manifests/msstore-agentic-dev.txt` 为准。Docker Engine 由 WSL 侧脚本安装。

## 5. 初始化 WSL 主开发环境

进入 WSL 后先预览：

```bash
./wsl/bootstrap.sh --base --cli --k8s --plan
```

安装基础开发、CLI 和 K8s 工具链：

```bash
./wsl/bootstrap.sh --base --cli --k8s
```

安装 Docker Engine 到 WSL：

```bash
./wsl/bootstrap.sh --docker
```

安装 Docker 后重启 WSL：

```powershell
wsl --shutdown
```

重新进入 WSL 后确认：

```bash
docker version
docker compose version
```

## 6. 恢复账号和基础配置

这些内容不进入 Git，只恢复边界：

- Bitwarden 登录；
- Git 全局用户名、邮箱、签名策略；
- SSH / GPG 私钥；
- VS Code 登录、扩展同步或手工扩展清单；
- Windows Terminal / PowerShell profile；
- 浏览器扩展和登录状态；
- WSL shell、Git、SSH、kubeconfig、Docker 登录状态。

## 7. 按设备角色安装显式 Windows profile

常用组合示例：

```powershell
.\windows\bootstrap.ps1 -Profile daily,daily-extra,desktop-enhance -Report
.\windows\bootstrap.ps1 -Profile dev-extra -Report
.\windows\bootstrap.ps1 -Profile network,automation -Report
.\windows\bootstrap.ps1 -Profile media,media-toolkit -Report
.\windows\bootstrap.ps1 -Profile maintenance -Report
```

`k8s-toolkit` 是 Windows 侧备用层；主力 K8s 工具链已经放到 WSL。不要在没有明确需求时安装 `backup`、`backup-cli`、`sync-storage`、`security-toolkit`、`creative`、`proxy-core`、`local-ai`、`communication` 等强账号、强设备、大体积或维护类 profile。

## 8. Scoop CLI 工具层

Scoop 只作为 Windows 侧 CLI 备用层。主力 CLI 优先放 WSL。首次启用前先预览：

```powershell
.\windows\bootstrap.ps1 -WithScoop -Plan -Report
```

确认后安装：

```powershell
.\windows\bootstrap.ps1 -WithScoop -Report
```

## 9. 手工边界恢复

按需恢复以下内容：

- Tailscale 登录和设备授权；
- 代理订阅、节点、dashboard secret、TUN 服务化配置；
- Kopia / restic / rclone 等备份仓库连接；
- Syncthing / Cryptomator 等数据目录；
- 远控设备码和无人值守密码；
- Typora 等商业软件授权；
- Docker volume、镜像、registry 登录状态和 Compose 项目；
- WSL 发行版、home 目录、shell 配置、SSH/GPG；
- Kubernetes / K3s kubeconfig 和集群凭据；
- 本地模型数据和大体积缓存。

这些内容可以写脱敏模板，但不要提交真实值。

## 10. 更新和快照

查看可更新项：

```powershell
.\windows\update.ps1
```

执行更新：

```powershell
.\windows\update.ps1 -All
```

WSL 侧更新：

```bash
sudo apt update && sudo apt upgrade
mise upgrade
```

导出当前设备快照：

```powershell
.\windows\export.ps1
```

导出的快照只作为维护目录的输入，不等同于个人应用目录。

## 11. 收尾检查

```powershell
.\windows\validate.ps1
git status
```

提交前确认没有导出文件、报告、日志、私钥、订阅、授权、设备码、kubeconfig、Docker 凭据或备份密钥进入 Git。

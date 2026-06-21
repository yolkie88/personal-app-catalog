# Windows 恢复手册

这份手册描述从一台新 Windows 设备恢复到可用个人工作环境的推荐顺序。它不是完整自动化脚本；账号、授权、私钥、订阅、设备绑定和备份密钥仍按手工边界处理。

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

## 3. 先做预览和校验

```powershell
.\windows\validate.ps1
.\windows\bootstrap.ps1 -Plan -Report
```

`-Plan` 只展示将安装的 profile 和包，不会安装软件。`-Report` 会在 `windows/reports/` 下生成本次预览报告，该目录不应提交。

## 4. 安装默认层

默认层只包含 `core + agentic-dev`：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\windows\bootstrap.ps1 -Report
```

默认层完成后，优先确认这些内容：

- Chrome / Bitwarden 可用；
- Git / PowerShell / Windows Terminal 可用；
- VS Code / Codex / Claude 可用；
- WSL / Docker Desktop 是否需要重启或额外初始化。

AI 编程工具主线只保留 Codex 和 Claude；Copilot 不作为个人恢复目录的一部分。

## 5. 恢复账号和基础配置

这些内容不进入 Git，只恢复边界：

- Bitwarden 登录；
- Git 全局用户名、邮箱、签名策略；
- SSH / GPG 私钥；
- VS Code 登录、扩展同步或手工扩展清单；
- Windows Terminal / PowerShell profile；
- 浏览器扩展和登录状态。

## 6. 按设备角色安装显式 profile

常用组合示例：

```powershell
.\windows\bootstrap.ps1 -Profile daily,daily-extra,desktop-enhance -Report
.\windows\bootstrap.ps1 -Profile dev-extra,k8s-toolkit -Report
.\windows\bootstrap.ps1 -Profile network,automation -Report
.\windows\bootstrap.ps1 -Profile media,media-toolkit -Report
.\windows\bootstrap.ps1 -Profile maintenance -Report
```

不要在没有明确需求时安装 `backup`、`backup-cli`、`sync-storage`、`security-toolkit`、`creative`、`proxy-core`、`local-ai`、`communication` 等强账号、强设备、大体积或维护类 profile。

## 7. Scoop CLI 工具层

Scoop 只用于 CLI 和小型便携工具。首次启用前先预览：

```powershell
.\windows\bootstrap.ps1 -WithScoop -Plan -Report
```

确认后安装：

```powershell
.\windows\bootstrap.ps1 -WithScoop -Report
```

## 8. 手工边界恢复

按需恢复以下内容：

- Tailscale 登录和设备授权；
- 代理订阅、节点、dashboard secret、TUN 服务化配置；
- Kopia / restic / rclone 等备份仓库连接；
- Syncthing / Cryptomator 等数据目录；
- 远控设备码和无人值守密码；
- Typora 等商业软件授权；
- Docker / WSL 中的数据卷、发行版、服务端组件；
- Kubernetes / K3s kubeconfig 和集群凭据；
- 本地模型数据和大体积缓存。

这些内容可以写脱敏模板，但不要提交真实值。

## 9. 更新和快照

查看可更新项：

```powershell
.\windows\update.ps1
```

执行更新：

```powershell
.\windows\update.ps1 -All
```

导出当前设备快照：

```powershell
.\windows\export.ps1
```

导出的快照只作为维护目录的输入，不等同于个人应用目录。

## 10. 收尾检查

```powershell
.\windows\validate.ps1
git status
```

提交前确认没有导出文件、报告、日志、私钥、订阅、授权、设备码或备份密钥进入 Git。

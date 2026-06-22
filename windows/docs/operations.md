# 操作流程

## 校验

提交前或恢复前先运行：

```powershell
.\windows\validate.ps1
```

校验内容包括：

- `bootstrap.ps1` 支持的 profile 和 `windows/manifests/winget-*.json` 是否对应；
- winget manifest 是否是合法 JSON，且包含 `PackageIdentifier`；
- 不同 manifest 中是否有重复包；
- 每个 `bootstrap.ps1` profile 是否都在 README 或 `catalog.md` 有记录；
- `all` 在 `bootstrap.ps1` 与 `catalog.md` 中的集合是否一致；
- `scoop-cli.txt` 是否存在且包含有效包；
- `.gitignore` 是否包含导出、报告和关键本地数据的忽略规则。

CI（`.github/workflows/validate.yml`）会运行 `validate.ps1`，并对 `wsl/bootstrap.sh` 运行 `bash -n` 和 `shellcheck`。

## Windows 侧预览

恢复新设备前建议先预览：

```powershell
.\windows\bootstrap.ps1 -Plan -Report
```

`-Plan` 只展示将要安装的 profile 和包，不执行安装。`-Report` 会生成 `windows/reports/bootstrap-report-*.json` 和 `windows/reports/bootstrap-report-*.txt`。

组合 profile 也建议先预览：

```powershell
.\windows\bootstrap.ps1 -Profile daily,network,automation,dev-extra -WithScoop -Plan -Report
```

## Windows 侧安装

默认层：

```powershell
.\windows\bootstrap.ps1 -Report
```

显式 profile：

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
```

Scoop CLI：

```powershell
.\windows\bootstrap.ps1 -WithScoop -Report
```

组合安装：

```powershell
.\windows\bootstrap.ps1 -Profile daily,network,automation,dev-extra -WithScoop -Report
```

## WSL 侧初始化

WSL 侧是主开发、运维、Docker 和 CLI 执行环境。先预览：

```bash
./wsl/bootstrap.sh --base --cli --k8s --plan
```

安装基础开发和运维工具：

```bash
./wsl/bootstrap.sh --base --cli --k8s
```

安装 Docker Engine 到 WSL：

```bash
./wsl/bootstrap.sh --docker
```

Docker 安装后需要重启 WSL session：

```powershell
wsl --shutdown
```

然后重新进入 WSL。

## 更新

只读查看：

```powershell
.\windows\update.ps1
```

执行更新：

```powershell
.\windows\update.ps1 -All
```

包含 Scoop：

```powershell
.\windows\update.ps1 -All -IncludeScoop
```

代理核心、远控、硬件调校、驱动、授权软件不要盲目跟随批量更新。

WSL 侧更新按发行版和工具链分别处理：

```bash
sudo apt update && sudo apt upgrade
mise upgrade
```

## 导出设备快照

```powershell
.\windows\export.ps1
```

导出的快照只作为目录维护输入，不直接等同于个人应用目录。WSL 的 home、Docker volume、kubeconfig、SSH/GPG 等数据不通过该脚本导出。

## 维护流程

1. 新软件先判断来源类型：winget、Scoop、Store、GitHub、官方安装器、语言包管理器、Docker/WSL、便携。
2. 判断是否可自动恢复。
3. 判断是否涉及账号、授权、设备绑定或本地专属配置。
4. Windows GUI 工具放入合适 winget profile。
5. 开发 CLI、K8s、Docker、Node.js、Python 主力工具优先放入 `wsl/` 清单。
6. 如果不可自动恢复，写入 `sources.md`、`manual-boundaries.md` 或 `wsl/docs/wsl-boundaries.md`。
7. 如果只是尝鲜，不进入 manifest。
8. 修改完成后执行 `windows/validate.ps1`。

## Git 初始化

确认本地生成文件没有进入暂存区后再提交：

```powershell
git status
git add .gitignore README.md .github windows wsl
git commit -m "init application catalog"
```

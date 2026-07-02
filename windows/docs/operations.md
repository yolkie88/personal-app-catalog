# 操作流程

## 校验

提交前或恢复前先运行：

```powershell
.\windows\validate.ps1
```

WSL 发行版安装后，再运行：

```bash
bash wsl/validate.sh
```

校验内容包括：

- `bootstrap.ps1` 支持的 profile 和 `windows/manifests/winget-*.json` 是否对应；
- winget manifest 是否是合法 JSON，且包含 `PackageIdentifier`；
- Microsoft Store manifest 是否匹配已有 profile，且 Store ID 是否重复；
- 不同 manifest 中是否有重复包；
- 每个 `bootstrap.ps1` profile 是否都在 README 或 `catalog.md` 有记录；
- `all` 在 `bootstrap.ps1` 与 `catalog.md` 中的集合是否一致；
- `scoop-cli.txt` 是否存在且包含有效包；
- WSL 文件、包清单、mise 版本选择器和 Docker 清单是否有效；
- Windows `agentic-dev` 是否错误包含 Docker Desktop、Node.js LTS 或 Codex CLI 包；
- `.gitignore` 是否包含导出、报告和关键本地数据的忽略规则。

CI（`.github/workflows/validate.yml`）会运行 `validate.ps1`、`wsl/validate.sh`，并对 `wsl/bootstrap.sh` 和 `wsl/validate.sh` 运行 `bash -n` 与 `shellcheck`。

## Windows 侧预览

恢复新设备前建议先预览：

```powershell
.\windows\validate.ps1
.\windows\wsl-distro.ps1 -Plan
.\windows\bootstrap.ps1 -Plan -Report
```

`wsl-distro.ps1 -Plan` 只展示 WSL 发行版检查或安装计划，不安装发行版。`bootstrap.ps1 -Plan` 只展示将要安装的 profile 和包，不执行安装。它会同时显示 winget JSON manifest、Microsoft Store txt manifest 和 Scoop 清单中的安装计划。`-Report` 会生成 `windows/reports/bootstrap-report-*.json` 和 `windows/reports/bootstrap-report-*.txt`。

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

Microsoft Store 包跟随 profile 自动安装。例如 `agentic-dev` 会读取 `windows/manifests/msstore-agentic-dev.txt`。

Scoop CLI：

```powershell
.\windows\bootstrap.ps1 -WithScoop -Report
```

组合安装：

```powershell
.\windows\bootstrap.ps1 -Profile daily,network,automation,dev-extra -WithScoop -Report
```

## WSL 发行版准备

WSL 脚本必须在已安装的 Linux 发行版里执行。默认发行版基线是 `Ubuntu-26.04`：

```powershell
.\windows\wsl-distro.ps1 -Install -Distro Ubuntu-26.04 -SetDefault
```

如果要查看本机可安装的发行版名称：

```powershell
wsl --list --online
```

首次安装发行版后，需要启动该发行版一次，创建 Linux 用户和密码。

## WSL 网络与代理（apt 前置）

装完发行版、装 apt 包之前先把网络配好，否则受限网络下 `--base`（apt）可能拉不到包。

先配 mirrored networking：

```powershell
.\windows\configure.ps1 -Wsl   # 写入 %USERPROFILE%\.wslconfig
wsl --shutdown                 # 重启生效
```

再让 apt 走 Windows sing-box（mirrored 下 root 可达 `127.0.0.1:7890`；`sudo apt` 不继承 shell 代理变量，需单独配）：

```bash
sudo tee /etc/apt/apt.conf.d/99proxy >/dev/null <<'EOF'
Acquire::http::Proxy "http://127.0.0.1:7890";
Acquire::https::Proxy "http://127.0.0.1:7890";
EOF
```

基础包装完后可移除：`sudo rm -f /etc/apt/apt.conf.d/99proxy`。详见 `wsl/docs/proxy.md`。

## WSL 侧初始化

WSL 侧是主开发、运维、Docker 和 CLI 执行环境。进入 WSL 后先校验和预览：

```bash
bash wsl/validate.sh
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

代理核心、远控、硬件调校、驱动、授权软件不要盲目跟随批量更新。把这些包的 winget ID 写进 `windows/manifests/update-exclude.txt`（一行一个，`#` 注释，默认全部注释即不冻结任何包），再加 `-Exclude`，更新时会用 winget pin 把它们挂住，让 `winget upgrade --all` 跳过：

```powershell
.\windows\update.ps1 -Exclude              # 只读列出可升级项，并提示哪些会被挂住
.\windows\update.ps1 -All -Exclude         # 升级全部，但跳过排除清单里的包
```

被挂住的包保持 pin 状态。查看 `winget pin list`，释放某个用 `winget pin remove --id <id>`。

### 自动更新（计划任务）

`windows/schedule-update.ps1` 把上面的更新封成一个 Windows 计划任务（plan-first、幂等，`-Force` 重注册同名任务）。先预览：

```powershell
.\windows\schedule-update.ps1 -Exclude -Plan
```

注册（默认每周日 03:00 跑 `update.ps1 -All`）：

```powershell
.\windows\schedule-update.ps1 -Exclude                       # 每周日 03:00
.\windows\schedule-update.ps1 -Frequency Daily -Time 04:30 -Exclude -IncludeScoop
.\windows\schedule-update.ps1 -Elevated -Exclude             # 以最高权限运行，覆盖需提权的机器级升级
```

任务只在当前用户登录时运行（不存密码）。手动触发用 `Start-ScheduledTask -TaskName personal-app-catalog-update`，移除用 `.\windows\schedule-update.ps1 -Remove`。

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

1. 新软件先判断来源类型：winget、Microsoft Store、Scoop、GitHub、官方安装器、语言包管理器、Docker/WSL、便携。
2. 判断是否可自动恢复。
3. 判断是否涉及账号、授权、设备绑定或本地专属配置。
4. Windows GUI 工具按来源放入合适的 `winget-*.json` 或 `msstore-*.txt`。
5. WSL 发行版和开发基线写入 WSL 文档和 Windows 侧 `wsl-distro.ps1` 默认值。
6. 开发 CLI、K8s、Docker、Node.js、Python 主力工具优先放入 `wsl/` 清单。
7. 如果不可自动恢复，写入 `sources.md`、`manual-boundaries.md` 或 `wsl/docs/wsl-boundaries.md`。
8. 如果只是尝鲜，不进入 manifest。
9. 修改完成后执行 `windows/validate.ps1` 和 `bash wsl/validate.sh`。

## Git 初始化

确认本地生成文件没有进入暂存区后再提交：

```powershell
git status
git add .gitignore README.md .github windows wsl
git commit -m "init application catalog"
```

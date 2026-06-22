# WSL 使用说明

本项目按“Windows 负责 GUI 和系统集成，WSL 负责开发、运维、CLI 和容器运行时”的方式组织工具。

## 定位

WSL 是主开发执行环境，适合放：

- 代码仓库；
- Git、SSH、shell、脚本；
- Node.js、Python、uv、pnpm、mise 等语言和项目工具链；
- kubectl、Helm、k9s、stern 等 Kubernetes / K3s 工具；
- Docker Engine 和 Compose；
- 面向 Linux 服务端的命令行工具。

Windows 侧保留：

- VS Code、Codex、Claude 等入口工具；
- 浏览器、密码管理器、截图、播放器等 GUI 工具；
- DBeaver、Bruno、SourceGit、DevToys 等 Windows GUI 开发工具；
- PowerToys、Everything、Sysinternals、硬件和磁盘诊断工具。

## 发行版基线

WSL 本身只是 Windows 组件；必须先安装至少一个 Linux 发行版，才能运行 `bash`、`apt`、`./wsl/bootstrap.sh` 等命令。

本项目默认发行版基线为：

```text
Ubuntu-24.04
```

Windows 侧先检查或安装发行版：

```powershell
.\windows\wsl-distro.ps1 -Plan
.\windows\wsl-distro.ps1 -Install -Distro Ubuntu-24.04 -SetDefault
```

可用发行版名称以本机命令为准：

```powershell
wsl --list --online
```

首次安装发行版后，需要启动该发行版一次，创建 Linux 用户和密码。之后再进入 WSL 执行本项目的 `wsl/` 脚本。

## 推荐目录

代码仓库建议放在 WSL Linux 文件系统：

```bash
mkdir -p ~/projects
cd ~/projects
```

不要把主力代码仓库放在 `/mnt/c/Users/...` 下长期开发。Windows 侧可以通过 VS Code Remote WSL 打开 WSL 中的项目。

## 文档分工

| 文档 | 用途 |
|---|---|
| `wsl/docs/wsl.md` | WSL-first 开发环境原则和初始化流程 |
| `wsl/docs/tools.md` | WSL 工具用途、常用方式和恢复边界 |
| `wsl/docs/wsl-boundaries.md` | WSL 敏感配置、凭据和数据边界 |

## 校验

修改 WSL 脚本、包清单或文档后运行：

```bash
bash wsl/validate.sh
```

该脚本会检查 WSL 文件是否存在、包清单是否为空、清单是否有重复项、mise 工具是否带版本选择器，以及 Docker / Node 是否被误放回 Windows `agentic-dev`。

## 初始化

先预览：

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

安装 Docker 后需要重启当前 WSL session，或者执行：

```powershell
wsl --shutdown
```

然后重新进入 WSL。

## Docker 策略

本项目采用 WSL 内 Docker Engine 作为主容器运行时，不再在 Windows 默认层安装 Docker Desktop。

当前 Docker 安装脚本支持 Ubuntu 和 Debian WSL，会根据 `/etc/os-release` 自动选择 Docker apt 源。其他发行版需要单独补充安装逻辑。

推荐边界：

- Docker Engine 安装在主开发发行版内；
- 项目 volume、Compose 文件和开发脚本放在 WSL；
- Docker 登录状态、registry token 和私有镜像凭据不入库；
- 不同时维护 Docker Desktop 和 WSL 内 Docker Engine 两套主运行时。

## K8s 策略

Kubernetes / K3s 工具链优先在 WSL 使用：

```bash
kubectl
helm
k9s
kubectx
kubens
stern
oras
```

Windows 侧 `k8s-toolkit` 只作为备用或 GUI 场景补充。主力 kubeconfig 放在 WSL 的 `~/.kube/config`，不要提交到本仓库。

## 语言工具链策略

Node.js、Python、uv、pnpm、mise 等主力开发工具链优先放在 WSL。

Windows 侧保留 Python Install Manager，只用于少量 Windows 原生脚本或工具需求，不作为主项目开发 Python 来源。

## mise 激活与工具来源

`cli.txt`、`k8s.txt`、`docker.txt` 是 bootstrap 安装内容的唯一事实来源，脚本直接读取这些文件，不再单独硬编码工具列表。每个工具的用途、常用方式和恢复边界见 `wsl/docs/tools.md`。

`cli.txt` 和 `k8s.txt` 中的 `@latest` / `@lts` 是有意使用的浮动选择器，便于个人恢复时跟随上游；如果某个工具需要完全可复现，可以改成精确版本。

`bootstrap.sh --cli`（或 `--k8s`）会把下面这行幂等地写入 `~/.bashrc`，让 mise 管理的 node、python 等进入 PATH：

```bash
eval "$(mise activate bash)"
```

首次安装后需要新开一个 shell，或执行 `source ~/.bashrc`。使用 zsh 时改写 `mise activate zsh` 到 `~/.zshrc`。

`bootstrap.sh --base`/`--cli` 还会幂等写入 starship、zoxide、direnv、fzf 的 shell 钩子，每行用 `command -v` 守卫，工具没装时自动跳过。这些钩子目前只覆盖 bash；zsh 用户需自行改写对应的 `init zsh` / `hook zsh` 形式。

mise、Scoop、Docker 都通过上游安装脚本（`curl | sh`）引导，刻意不固定版本：好处是跟随上游修复，代价是恢复结果不完全可复现。

## 与 Windows 的分工

| 场景 | 推荐位置 |
|---|---|
| 写代码、跑测试、执行脚本 | WSL |
| Docker / Compose | WSL |
| K3s / Kubernetes 管理 | WSL |
| 截图、文档、播放器、浏览器 | Windows |
| 数据库 GUI、API GUI、Git GUI | Windows |
| 系统维护、硬件诊断 | Windows |

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

## 推荐目录

代码仓库建议放在 WSL Linux 文件系统：

```bash
mkdir -p ~/projects
cd ~/projects
```

不要把主力代码仓库放在 `/mnt/c/Users/...` 下长期开发。Windows 侧可以通过 VS Code Remote WSL 打开 WSL 中的项目。

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

## 与 Windows 的分工

| 场景 | 推荐位置 |
|---|---|
| 写代码、跑测试、执行脚本 | WSL |
| Docker / Compose | WSL |
| K3s / Kubernetes 管理 | WSL |
| 截图、文档、播放器、浏览器 | Windows |
| 数据库 GUI、API GUI、Git GUI | Windows |
| 系统维护、硬件诊断 | Windows |

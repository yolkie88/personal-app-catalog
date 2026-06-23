# 容器运行时候选方案

本文件记录 WSL-first 开发环境中的容器运行时选择。

## 当前默认方案

当前默认方案仍然是把 Docker Engine 安装到主力 WSL Linux 发行版中：

```bash
./wsl/bootstrap.sh --docker
```

该方案继续作为本项目的稳定基线：Linux 原生、和服务器环境接近、Docker / Compose 生态成熟，并且已经接入当前 `wsl/bootstrap.sh`。

## 候选方案：WSL Containers

WSL Containers 记录为未来候选容器运行时，不作为当前默认方案。

在目标 Windows 设备上可用并完成验证前，不要因为本机出现相关命令就替换 Docker Engine in WSL。

## 未来可能替代的场景

如果 WSL Containers 后续能力稳定，可能替代以下本地开发角色：

- Docker Desktop：适合只需要本地 Linux 容器、不需要 Docker Desktop GUI 和企业桌面能力的场景。
- Docker Engine in WSL：适合简单 `run`、`build`、镜像、volume、端口映射等本地容器场景。
- 部分 Compose 本地服务编排：前提是 Compose 或等价多服务工作流足够成熟。

## 晋升为可选方案前必须验证

在修改本项目默认容器策略前，至少在干净 Windows 设备上验证：

- 基础运行：run、stop、remove、logs、exec、端口映射。
- 镜像生命周期：pull、build、tag、push、registry login。
- Compose 或等价多服务工作流。
- BuildKit / buildx 或等价镜像构建能力。
- Windows、WSL、runtime VM 之间的 bind mount 行为。
- named volume 的备份、清理和迁移行为。
- localhost 访问和容器间网络行为。
- VS Code Dev Containers 兼容性。
- Testcontainers 和常见开发框架兼容性。
- credential、secret、registry token 的存储与边界。
- 资源限制、磁盘占用、清理、升级和卸载行为。

## 决策规则

- Docker Engine in WSL 继续作为默认方案，直到 WSL Containers 通过验证清单。
- 不把 WSL Containers 加进 `wsl/bootstrap.sh` 的默认路径。
- 即使后续采用，也先做成显式可选 runtime path，而不是直接替代现有 Docker Engine 方案。
- Docker Desktop 继续不进入 Windows 默认层；只有未来明确设备角色需要 Docker Desktop GUI / 企业能力时，才单独建显式 profile。

## 当前状态

状态：候选 / 观察。

下一步：等目标 Windows 版本可用后，按验证清单测试端到端容器工作流。

# WSL 工具说明

本文件记录 WSL 侧工具的用途、使用方式和恢复边界。它不是 Linux 命令百科，重点是帮助判断：为什么这个工具放在 WSL、平时怎么用、哪些数据或配置不能进入仓库。

## 基础包：`wsl/packages/apt-base.txt`

这些包通过发行版包管理器安装，定位是 WSL 的基础系统能力和常用命令行底座。

| 工具 | 用途 | 常用方式 | 恢复边界 |
|---|---|---|---|
| build-essential | C/C++ 编译基础工具链 | 编译 native 依赖、Python/Node 原生扩展 | 构建产物不入库 |
| ca-certificates | CA 证书 | HTTPS、curl、git、Docker repo 等基础依赖 | 自定义内网 CA 需手工处理 |
| curl | HTTP 下载和 API 调试 | `curl <url>`、下载安装脚本 | token、cookie、私有 URL 不写入公共脚本 |
| git | 版本控制 | `git clone`、`git status`、`git diff` | 用户名、邮箱、签名、SSH/GPG 手工恢复 |
| gnupg | GPG 密钥和签名 | 包源 key、Git 签名、加密文件 | `~/.gnupg/` 不入库 |
| lsb-release | 发行版信息 | 脚本判断 Ubuntu/Debian 版本 | 无明显边界 |
| openssh-client | SSH 客户端 | 连接服务器、Git SSH、rsync over SSH | `~/.ssh/` 不入库 |
| pkg-config | 编译依赖探测 | native build 查找库和头文件 | 无明显边界 |
| software-properties-common | apt 仓库管理辅助 | 添加 apt repo、PPA 等 | 第三方源需明确来源和可信度 |
| unzip / zip | 压缩解压 | 解压 release、打包临时文件 | 生成包和缓存不入库 |
| rsync | 文件同步 | 同步服务器、备份目录、迁移文件 | 远端地址和密钥手工处理 |
| jq | JSON 处理 | `jq . file.json`、API 输出过滤 | 处理含 token 的 JSON 时避免提交输出 |
| ripgrep | 文本搜索 | `rg keyword` | 无明显边界 |
| fd-find | 文件查找 | Ubuntu/Debian 命令可能是 `fdfind`，脚本会链接为 `fd` | 无明显边界 |
| fzf | 模糊选择 | shell 历史、文件、分支选择 | shell hook 写入 `.bashrc`，个人历史不入库 |
| bat | 文件查看 | Ubuntu/Debian 命令可能是 `batcat`，脚本会链接为 `bat` | 主题配置按设备处理 |
| direnv | 目录级环境变量 | 进入项目目录自动加载 `.envrc` | `.envrc` 可以入库，真实 secret 不入库 |
| tmux | 终端复用 | 长任务、远程会话、多窗口操作 | session 状态不入库，配置可单独模板化 |
| shellcheck | Shell 静态检查 | `shellcheck script.sh` | 无明显边界 |

## 主力开发 CLI：`wsl/packages/cli.txt`

这些工具通过 mise 管理。清单里的 `@latest` / `@lts` 是有意使用的浮动选择器，便于个人环境跟随上游；需要完全可复现时再改成精确版本。

| 工具 | 用途 | 常用方式 | 恢复边界 |
|---|---|---|---|
| node@lts | Node.js LTS 运行时 | 前端、脚本、AI 工具链、构建任务 | 全局包和缓存不入库；项目依赖跟随项目仓库 |
| python@latest | Python 运行时 | 脚本、数据处理、开发工具链 | 虚拟环境和包缓存不入库 |
| uv@latest | Python 包和项目工具 | `uv run`、`uv sync`、`uvx` | 项目锁文件跟随项目；全局缓存不入库 |
| pnpm@latest | Node 包管理器 | `pnpm install`、monorepo 管理 | store 缓存不入库 |
| neovim@latest | 终端编辑器 | 快速编辑、远程编辑、Git commit message | 个人配置可单独维护，不建议塞入本仓库 |
| lazygit@latest | Git TUI | 查看状态、提交、分支、rebase 辅助 | Git 账号、签名和密钥仍按 Git 配置恢复 |
| delta@latest | Git diff 增强 | 作为 `git diff` pager | Git pager 配置可模板化 |
| zoxide@latest | 智能目录跳转 | `z <dir>` | 目录历史按设备生成，不入库 |
| starship@latest | Shell prompt | 统一 bash/zsh prompt | 字体和主题配置按设备或模板处理 |
| just@latest | 命令任务入口 | `just test`、`just dev`、`just deploy` | `justfile` 跟随项目仓库 |
| gh@latest | GitHub CLI | `gh pr`、`gh repo`、`gh run`、`gh auth` | `gh auth` 登录状态和 token 不入库 |
| yq@latest | YAML 处理 | K8s manifest、配置文件、CI YAML 修改 | 处理含 secret 的 YAML 时不要提交输出 |

## Kubernetes / K3s 工具：`wsl/packages/k8s.txt`

K8s/K3s 主力操作优先放 WSL，Windows 侧 `k8s-toolkit` 只作为备用。

| 工具 | 用途 | 常用方式 | 恢复边界 |
|---|---|---|---|
| kubectl@latest | Kubernetes CLI | `kubectl get pods`、`kubectl apply -f` | `~/.kube/config` 不入库 |
| helm@latest | Kubernetes 包管理 | `helm install`、`helm upgrade`、`helm template` | 私有 repo、values、凭据不入库 |
| k9s@latest | Kubernetes TUI | 交互式查看 Pod、日志、事件、资源 | 依赖 kubeconfig；主题和快捷键按设备处理 |
| kubectx@latest | context 切换 | 快速切换多集群 context | 不保存凭据，只依赖 kubeconfig |
| kubens@latest | namespace 切换 | 快速切换 namespace | 不保存凭据，只依赖 kubeconfig |
| stern@latest | 多 Pod 日志聚合 | `stern app-name -n namespace` | 只在有权限的集群使用 |
| oras@latest | OCI artifact 工具 | 推拉 OCI artifact、Chart、非镜像制品 | registry 登录状态和 token 不入库 |

## Docker Engine：`wsl/packages/docker.txt`

Docker 放在 WSL 内作为主容器运行时，不在 Windows 默认层安装 Docker Desktop。

| 工具 | 用途 | 常用方式 | 恢复边界 |
|---|---|---|---|
| docker-ce | Docker Engine 服务端 | 运行容器、管理镜像、Compose 后端 | 镜像、volume、容器状态不入库 |
| docker-ce-cli | Docker CLI | `docker ps`、`docker run`、`docker logs` | `~/.docker/config.json` 不入库 |
| containerd.io | 容器运行时依赖 | Docker Engine 底层运行时 | 不单独维护配置，随 Docker 管理 |
| docker-buildx-plugin | 多平台构建插件 | `docker buildx build` | builder 状态和缓存不入库 |
| docker-compose-plugin | Compose 插件 | `docker compose up -d` | Compose 文件可入项目，`.env` 和数据卷不入库 |

## Agentic 编码 CLI：`wsl/packages/agents.txt`

Claude Code、Codex CLI 用各自官方原生安装器（`curl | sh`）装到 `~/.local/bin`，自带后台自更新。`bootstrap.sh --agents` 只做首次安装（二进制已存在则跳过），更新交给工具自己——和 winget 侧"自更新 app 不进批量升级"同理。Windows 上的 Claude / Codex 桌面 App 是 GUI 入口，与这里的 CLI 互补。

| 工具 | 用途 | 安装/更新 | 恢复边界 |
|---|---|---|---|
| claude（Claude Code） | 终端 agentic 编码 | `curl -fsSL https://claude.ai/install.sh \| bash`；后台自更新 | 登录、权限、项目上下文手工恢复，不入库 |
| codex（Codex CLI） | 终端 agentic 编码 | `curl -fsSL https://chatgpt.com/codex/install.sh \| sh`；自更新 | ChatGPT/API 登录状态不入库 |

> 首次运行需登录（`claude` / `codex`），属手工边界。受限网络下先 `proxy_on` 再装。

## 脚本和校验工具

| 文件 | 用途 | 常用方式 | 恢复边界 |
|---|---|---|---|
| `wsl/bootstrap.sh` | WSL 初始化脚本 | `./wsl/bootstrap.sh --base --cli --k8s --plan` | 执行前先读计划；会写入 `.bashrc` shell hook |
| `wsl/validate.sh` | WSL 侧校验 | `bash wsl/validate.sh` | 只做结构和清单校验，不验证真实安装成功 |

## 使用原则

- 代码仓库优先放 `~/projects` 等 WSL Linux 文件系统目录。
- 主项目 Node.js、Python、Docker、K8s、CLI 工具链优先在 WSL 内使用。
- Windows 侧保留 GUI、账号客户端、截图、浏览器、系统维护工具和开发 GUI。
- `~/.ssh/`、`~/.gnupg/`、`~/.kube/config`、`~/.docker/config.json`、`.env`、registry token、Docker volume 不进入仓库。

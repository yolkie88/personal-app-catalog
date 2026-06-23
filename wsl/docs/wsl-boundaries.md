# WSL 边界

WSL 是主开发执行环境，但不代表可以把 Linux home 目录整体纳入 Git。本文件记录哪些内容可以模板化，哪些内容必须手工恢复。

## 可以入库的内容

可以提交脱敏模板或说明：

- shell 初始化片段；
- `.gitconfig` 示例；
- `.editorconfig` 示例；
- `.tool-versions` / `.mise.toml` 示例；
- Docker Compose 示例；
- Kubernetes values 示例；
- 目录结构说明；
- 常用 alias 说明；
- 不含真实地址和凭据的配置模板。

## 不入库的内容

以下内容不应进入本仓库：

- `~/.ssh/`；
- `~/.gnupg/`；
- `~/.kube/config`；
- `~/.docker/config.json`；
- `~/.config/gh/`；
- `~/.aws/`、`~/.azure/`、`~/.config/gcloud/`；
- `.npmrc` 中的 token；
- registry 登录信息；
- Docker volume；
- 数据库 dump；
- 私有 Helm values；
- `.env`；
- 模型权重、缓存和大体积数据；
- 代理订阅、节点和 dashboard secret。

## 配置层

`wsl/config/` 下的工具配置模板（nvim、starship、tmux、bat、lazygit、git、bash 别名）属于上面"可以入库"的脱敏模板范畴，由 `./wsl/bootstrap.sh --config` 应用，覆盖前先备份。详见 `config.md`。

身份（`user.name` / `user.email`）、SSH/GPG、kubeconfig、shell 历史、zoxide 历史、neovim 插件锁文件等仍按本文件其余部分手工恢复或按设备生成，不进入仓库。

## 代码目录

建议：

```bash
~/projects
~/work
~/sandbox
```

长期开发项目应放在 WSL Linux 文件系统，不建议放在 `/mnt/c/Users/...` 下。

## Docker 数据

Docker Engine 放在 WSL 内时，数据目录、镜像、volume 和 registry 登录状态都属于本机状态，不归本仓库管理。

迁移设备时优先恢复：

1. Compose 文件和项目仓库；
2. 必要的数据备份；
3. registry 登录；
4. volume 或数据库恢复。

不要尝试把整个 Docker 数据目录直接提交或复制进本仓库。

## kubeconfig

`~/.kube/config` 和集群凭据必须手工恢复。可以在项目文档中记录集群名称、用途、访问方式和负责人，但不要记录真实 token、证书或私有地址。

## 代理和网络

WSL 代理依赖 Windows 网络、TUN、DNS 和具体代理客户端状态。可以记录代理策略，但不要提交真实订阅、节点、secret 或 dashboard 配置。

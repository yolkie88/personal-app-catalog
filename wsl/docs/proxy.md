# WSL 代理策略

本项目采用 Windows mihomo 为代理入口，WSL 通过 mirrored networking、autoProxy 和显式环境变量使用代理。

默认目标：新机恢复时代理常开，因为受限网络下没有代理 `apt`、Docker、mise、Git 和 agentic CLI 都可能无法安装或使用。代理地址本身可以模板化，节点、订阅、secret 和账号状态仍然不入库。TUN 仍不默认启用，作为最后兜底。

## Windows 侧前提

mihomo 推荐监听本机：

```text
127.0.0.1:7890
```

Windows 全局 WSL 配置放在 `%UserProfile%\.wslconfig`。可手工创建，也可用配置层一键写入（plan-first、覆盖前备份，模板见 `windows/config/wsl/wslconfig`）：

```powershell
.\windows\configure.ps1 -Wsl -Plan   # 预览
.\windows\configure.ps1 -Wsl          # 应用（-All 也包含它）
```

模板内容：

```ini
[wsl2]
networkingMode=mirrored
dnsTunneling=true
autoProxy=true
firewall=true
```

修改后重启 WSL 生效：

```powershell
wsl --shutdown
```

mirrored 模式下，WSL 通常可以直接访问 Windows 本机的 `127.0.0.1:7890`。

## 常开代理一键配置

进入已重启后的 WSL，先配置代理，再安装工具链：

```bash
./wsl/bootstrap.sh --proxy --plan
./wsl/bootstrap.sh --proxy
```

默认写入：

- `~/.config/personal-app-catalog/proxy.env`：shell 常开 `http_proxy` / `https_proxy` / `all_proxy` / `no_proxy`；
- `~/.bashrc`：source 上面的 `proxy.env`，以后新 shell 自动带代理；
- `/etc/apt/apt.conf.d/99proxy`：让 `sudo apt` 也走代理；
- `~/.config/git/catalog-proxy.gitconfig` + `~/.gitconfig` include：Git HTTPS 代理；
- `/etc/systemd/system/docker.service.d/proxy.conf`：Docker daemon 代理；
- `~/.docker/config.json`：仅当文件不存在时写 Docker build/client 代理；若已有文件则跳过，避免覆盖 registry 登录凭据。

默认入口是 Windows mihomo 的 `127.0.0.1:7890`。如端口不同：

```bash
./wsl/bootstrap.sh --proxy --proxy-host 127.0.0.1 --proxy-port 7890
```

常用完整新机顺序：

```bash
./wsl/bootstrap.sh --proxy
./wsl/bootstrap.sh --base --cli --k8s --config --agents
./wsl/bootstrap.sh --docker --proxy
```

也可以用：

```bash
./wsl/bootstrap.sh --all
```

`--all` 会先配置代理，再安装 apt / mise / Docker / agentic CLI。

## autoProxy 与 proxy_on 如何配合

`.wslconfig` 里的 `autoProxy=true`、`bootstrap.sh --proxy` 和下面的 `proxy_on` 不是二选一，而是分工，理解这点能避免叠加和困惑：

- **`autoProxy`（自动、被动）**：WSL 发行版启动时，会根据 **Windows 系统代理**自动注入 `HTTP_PROXY` / `HTTPS_PROXY` 等环境变量。所以当 mihomo 已开启系统代理时，新开的 WSL shell **通常已经有代理**，不需要再 `proxy_on`。它一般只给 http/https，不一定给 `all_proxy`（SOCKS）。
- **`bootstrap.sh --proxy`（持久、主动）**：本项目默认恢复路径。它不依赖 Windows 系统代理是否开启，直接写 WSL 内的 shell、apt、Git 和 Docker 代理配置。
- **`proxy_on`（临时、主动）**：用于临时覆盖当前 shell 的代理 host/port，或在没有运行 `--proxy` 的临时环境里手动启用代理。

需要注意的叠加关系：

- 如果 autoProxy 或 `proxy.env` 已注入代理，再 `proxy_on` 只是覆盖成相同/自定义的值，影响不大。
- `proxy_off` 只影响当前 shell，它不会删除 `proxy.env`、apt、Git 或 Docker 的持久代理。要恢复常开代理，新开一个 shell 即可。
- 判断当前 shell 到底有没有代理、是谁给的，用 `proxy_status` 和 `proxy_test`（见下）。

## apt（系统包，sudo 场景）

`sudo apt` **不继承**你 shell 里的 `http_proxy` / `https_proxy`（autoProxy 注入的也一样），Ubuntu 默认 sudoers 不 `env_keep` 这些变量。所以即使 `proxy_on`，`sudo apt update` 仍可能连不上——这就是新机首次 `./wsl/bootstrap.sh --base` 在受限网络下装不上 apt 包的原因。

`./wsl/bootstrap.sh --proxy` 会写 `/etc/apt/apt.conf.d/99proxy`，不需要手工 tee。由于代理常开，保留该文件；如果某台设备改成直连网络，再手工移除它。

## Shell 临时代理函数

这些函数来自**配置层**，不随装包自动出现。`wsl/bootstrap.sh --base --cli --k8s --docker` 只装软件、不碰配置；要拿到下面的代理开关，需显式应用配置模板（`--config`，或包含它的 `--all`）：

```bash
./wsl/bootstrap.sh --config --plan   # 先预览（会先备份现有文件）
./wsl/bootstrap.sh --config          # 应用
```

应用后 `wsl/config/bash/aliases.sh` 提供以下函数：

```bash
proxy_on
proxy_status
proxy_off
proxy_test
```

`./wsl/bootstrap.sh --proxy` 写入的 `proxy.env` 会让新 shell 自动带上这些环境变量；`proxy_on` 则只修改当前 shell session：

```bash
http_proxy=http://127.0.0.1:7890
https_proxy=http://127.0.0.1:7890
all_proxy=socks5h://127.0.0.1:7890
no_proxy=localhost,127.0.0.1,::1,.local,.internal,.svc,.cluster.local,10.0.0.0/8
```

`no_proxy` 里的 `.svc` / `.cluster.local` / `10.0.0.0/8` 是为 k8s、Docker 等内网流量准备的，避免集群内部、私网地址被代理污染。如果你的私网用的是别的网段（如 `172.16.0.0/12`、`192.168.0.0/16`），按需在本机追加。

临时覆盖代理：

```bash
proxy_on
curl https://github.com
```

当前 shell 临时关闭：

```bash
proxy_off
```

自检连通性和出口 IP（`curl` 会自动读取代理环境变量，无论是 `proxy_on` 还是 autoProxy 注入的）：

```bash
proxy_test
```

不要在 `.bashrc` 里直接调用 `proxy_on`；常开代理由 `proxy.env` 管理，便于脚本重写、排查和移除。`no_proxy` 默认包含本机、`.svc` / `.cluster.local` 以及 `10.0.0.0/8`、`172.16.0.0/12`、`192.168.0.0/16`，尽量避免内网、Kubernetes、Docker 私网被代理污染。

## Git

`./wsl/bootstrap.sh --proxy` 会写 `~/.config/git/catalog-proxy.gitconfig`，并在 `~/.gitconfig` 里加入 include。这样即使 `--proxy` 早于 `--base` 执行，Git 安装后也会自动读取代理。这是有意的：新机恢复时 GitHub、mise 插件、源码下载都依赖 Git HTTPS 可用。

如果确实需要 Git SSH 走 SOCKS，可在个人 `~/.ssh/config` 手工配置，不入库：

```sshconfig
Host github.com
  HostName github.com
  User git
  ProxyCommand nc -X 5 -x 127.0.0.1:7890 %h %p
```

需要 `netcat-openbsd`：

```bash
sudo apt install -y netcat-openbsd
```

## Node / Python / Go / Rust

这些工具优先读取 `proxy.env` 注入的环境变量：

```bash
npm install
pnpm install
uv sync
pip install -r requirements.txt
go mod download
cargo fetch
```

默认不额外写 npm / pnpm / pip / cargo 的全局代理配置，避免多处状态漂移。常开 shell 环境变量已经覆盖大多数下载路径。

## Docker Engine in WSL

用户 shell 的代理环境变量不一定会影响 Docker daemon。`./wsl/bootstrap.sh --proxy` 会写 systemd drop-in；如果 Docker 已安装并运行，会 reload 并 restart Docker。`./wsl/bootstrap.sh --docker --proxy` 会在安装 Docker 后再写一次 daemon 代理。

Docker build 也可以按需传入 build args：

```bash
docker build \
  --build-arg HTTP_PROXY=http://127.0.0.1:7890 \
  --build-arg HTTPS_PROXY=http://127.0.0.1:7890 \
  .
```

## VS Code Remote WSL

VS Code 有两个代理面：

- Windows VS Code 主进程：优先跟随 Windows 系统代理。
- WSL extension host / terminal / language server：按 WSL 内环境变量处理。

因此扩展市场、登录、Settings Sync 主要看 Windows 侧；项目依赖安装、Git、语言服务器下载等主要看 WSL 侧。

## TUN 兜底

TUN 只作为问题软件兜底，不作为默认常开方案。

优先顺序：

1. 应用内代理。
2. 当前 shell 环境变量。
3. per-app 代理。
4. 临时 TUN。

## 移除或改代理

改端口或 host：

```bash
./wsl/bootstrap.sh --proxy --proxy-host 127.0.0.1 --proxy-port 7890
```

临时关闭当前 shell：

```bash
proxy_off
```

彻底关闭持久代理需要手工移除本机运行期配置：

```bash
rm -f ~/.config/personal-app-catalog/proxy.env
rm -f ~/.config/git/catalog-proxy.gitconfig
# 再从 ~/.gitconfig 中移除 personal-app-catalog proxy include 块
sudo rm -f /etc/apt/apt.conf.d/99proxy
sudo rm -f /etc/systemd/system/docker.service.d/proxy.conf
sudo systemctl daemon-reload
```

`~/.docker/config.json` 若由本脚本创建且没有 registry 登录信息，可手工删除；如果里面有 `auths`，不要整文件删除。

## 边界

- 代理地址可以作为模板默认值，订阅、节点、token、secret 不入库。
- 不把代理配置写进 Dockerfile、Compose、项目 `.env` 后提交。
- `--proxy` 是显式运行期配置，会写 home、Git global、apt 和 systemd；执行前先跑 `--plan`。
- 代理配置以“常开、可诊断、可恢复”为原则。

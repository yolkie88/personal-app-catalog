# WSL 代理策略

本项目采用 Windows mihomo 为代理入口，WSL 通过 mirrored networking、autoProxy 和显式环境变量按需使用代理。

默认目标：轻量、可开关、少副作用。不要默认启用 TUN，也不要长期把代理写死到 Git / npm / pip 等全局配置里。

## Windows 侧前提

mihomo 推荐监听本机：

```text
127.0.0.1:7890
```

Windows 全局 WSL 配置建议放在 `%UserProfile%\.wslconfig`：

```ini
[wsl2]
networkingMode=mirrored
dnsTunneling=true
autoProxy=true
firewall=true
```

修改后重启 WSL：

```powershell
wsl --shutdown
```

mirrored 模式下，WSL 通常可以直接访问 Windows 本机的 `127.0.0.1:7890`。

## autoProxy 与 proxy_on 如何配合

`.wslconfig` 里的 `autoProxy=true` 和下面的 `proxy_on` 不是二选一，而是分工，理解这点能避免叠加和困惑：

- **`autoProxy`（自动、被动）**：WSL 发行版启动时，会根据 **Windows 系统代理**自动注入 `HTTP_PROXY` / `HTTPS_PROXY` 等环境变量。所以当 mihomo 已开启系统代理时，新开的 WSL shell **通常已经有代理**，不需要再 `proxy_on`。它一般只给 http/https，不一定给 `all_proxy`（SOCKS）。
- **`proxy_on`（手动、主动）**：用于以下场景——系统代理没开但你只想让某个 shell 走代理；或需要 `all_proxy`/SOCKS；或想临时改 host/port。

需要注意的叠加关系：

- 如果 autoProxy 已注入代理，再 `proxy_on` 只是覆盖成相同/自定义的值，影响不大。
- 但 `proxy_off` 是 `unset`，它**不会恢复** autoProxy 注入的值——要恢复 autoProxy 的自动代理，新开一个 shell 即可。
- 判断当前 shell 到底有没有代理、是谁给的，用 `proxy_status` 和 `proxy_test`（见下）。

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

`proxy_on` 只修改当前 shell session 的环境变量：

```bash
http_proxy=http://127.0.0.1:7890
https_proxy=http://127.0.0.1:7890
all_proxy=socks5h://127.0.0.1:7890
no_proxy=localhost,127.0.0.1,::1,.local,.internal,.svc,.cluster.local,10.0.0.0/8
```

`no_proxy` 里的 `.svc` / `.cluster.local` / `10.0.0.0/8` 是为 k8s、Docker 等内网流量准备的，避免集群内部、私网地址被代理污染。如果你的私网用的是别的网段（如 `172.16.0.0/12`、`192.168.0.0/16`），按需在本机追加。

需要代理时显式开启：

```bash
proxy_on
curl https://github.com
```

不用时关闭：

```bash
proxy_off
```

自检连通性和出口 IP（`curl` 会自动读取代理环境变量，无论是 `proxy_on` 还是 autoProxy 注入的）：

```bash
proxy_test
```

建议不要在 `.bashrc` 里默认调用 `proxy_on`。否则访问内网仓库、Kubernetes、数据库、局域网服务时容易被代理污染。

## Git

Git HTTPS 通常会读取 `http_proxy` / `https_proxy`：

```bash
proxy_on
git ls-remote https://github.com/yolkie88/personal-app-catalog.git
```

不建议默认写：

```bash
git config --global http.proxy http://127.0.0.1:7890
git config --global https.proxy http://127.0.0.1:7890
```

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

优先让工具读取环境变量：

```bash
proxy_on
npm install
pnpm install
uv sync
pip install -r requirements.txt
go mod download
cargo fetch
```

不要默认持久化 npm / pnpm / pip 的代理配置。只有某个项目确实需要时，才在项目级别或当前 shell 中显式设置。

## Docker Engine in WSL

用户 shell 的代理环境变量不一定会影响 Docker daemon。`docker pull` 和部分 build 流量可能需要 systemd drop-in：

```bash
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo tee /etc/systemd/system/docker.service.d/proxy.conf >/dev/null <<'EOF'
[Service]
Environment="HTTP_PROXY=http://127.0.0.1:7890"
Environment="HTTPS_PROXY=http://127.0.0.1:7890"
Environment="NO_PROXY=localhost,127.0.0.1,::1"
EOF

sudo systemctl daemon-reload
sudo systemctl restart docker
```

该配置是本机运行期状态，不由 `wsl/bootstrap.sh` 默认写入。

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

## 边界

- 代理地址可以作为模板默认值，订阅、节点、token、secret 不入库。
- 不把代理配置写进 Dockerfile、Compose、项目 `.env` 后提交。
- 不把代理作为 bootstrap 默认安装副作用。
- 代理配置以“可开关、可诊断、可恢复”为原则。

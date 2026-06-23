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

## Shell 临时代理函数

`wsl/config/bash/aliases.sh` 提供以下函数：

```bash
proxy_on
proxy_status
proxy_off
```

`proxy_on` 只修改当前 shell session 的环境变量：

```bash
http_proxy=http://127.0.0.1:7890
https_proxy=http://127.0.0.1:7890
all_proxy=socks5h://127.0.0.1:7890
no_proxy=localhost,127.0.0.1,::1,.local,.internal
```

需要代理时显式开启：

```bash
proxy_on
curl https://github.com
```

不用时关闭：

```bash
proxy_off
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

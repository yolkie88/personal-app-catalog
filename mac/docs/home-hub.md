# Mac mini 家庭枢纽

`home-hub` profile 面向一台长期开机的 Mac mini：它负责远程访问、同步、备份、代理核心、局域网诊断和部分家庭服务入口。这个 profile 只安装工具，不自动启用服务，也不提交真实服务配置。

## 安装

先预览：

```bash
./mac/bootstrap.sh --profile home-hub --plan
```

安装：

```bash
./mac/bootstrap.sh --profile home-hub
```

## 服务启用原则

`mac/packages/services-home-hub.txt` 记录了可考虑启用的服务：

| 服务 | 建议 scope | 说明 |
|---|---|---|
| Syncthing | user | 用户级同步服务，设备 ID 和共享目录手工配置 |
| Caddy | root | 需要绑定低端口或统一反向代理时用 root service |
| sing-box | root | TUN/系统代理核心通常需要更高权限 |
| Mosquitto | user | MQTT broker 候选，密码和 ACL 手工配置 |

启用前先读 Homebrew 给出的 plist/caveat，再决定 user/root：

```bash
brew services info syncthing
brew services start syncthing
sudo brew services start caddy
```

不要让多个 TUN/透明代理核心同时常驻。sing-box、Mihomo、Shadowrocket、系统 VPN/Tailscale 的 DNS 和路由要一次只调整一个变量。

## 代理和 Tailscale

本机历史上有 Homebrew `sing-box` 根守护进程使用记录。约定：

- Homebrew 安装二进制，真实配置放在本机运行目录，不提交到本仓库；
- `sing-box` 的运行态、cache、dashboard secret、订阅和节点不入库；
- Tailscale 登录、MagicDNS/CorpDNS、exit node、route approval 按设备手工恢复；
- 如果 sing-box 接管 DNS，Tailscale 的 DNS 接管需要单独验证，避免两边同时改 DNS。

## 备份和同步

Kopia、restic、rclone、Syncthing 只自动安装工具：

- 仓库地址、密码、keyfile、对象存储凭据不入库；
- 备份计划、排除规则和保留策略先在本机验证，再用脱敏文档记录；
- Syncthing 的 device ID、folder ID、ignore patterns 和 discovery state 按设备恢复。

## 远程访问

Tailscale 是首选管理平面，RustDesk 是备用远控入口。RustDesk 的设备码、无人值守密码、自建 relay/server 配置不入库。

## 监控和排障

`smartmontools`、`nmap`、`iperf3`、`mtr`、`wakeonlan` 用于本地排障。扫描目标、局域网拓扑、设备清单和日志可能暴露家庭网络结构，不提交。


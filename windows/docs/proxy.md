# Windows 代理策略

本项目采用“mihomo 内核 + Web UI + 系统代理优先”的轻量方案。

目标是让浏览器、GUI 工具和大多数桌面应用优先走 Windows 系统代理；少量不读取系统代理的软件再单独处理；TUN 只作为兜底方案，不作为默认常开路径。

## 推荐拓扑

```text
mihomo core + Web UI
  -> Windows 系统代理 / WinINET
  -> 按需同步 WinHTTP
  -> WSL mirrored + autoProxy + 显式环境变量
  -> 少数软件单独配置应用内代理 / per-app proxy / 临时 TUN
```

## mihomo 基线

推荐只监听本机：

```yaml
mixed-port: 7890
allow-lan: false
bind-address: 127.0.0.1
external-controller: 127.0.0.1:9090
secret: "replace-with-local-secret"
mode: rule
log-level: info
```

原则：

- Web UI 只连接 `127.0.0.1:9090`。
- 默认不开 `allow-lan`，避免把代理暴露给局域网。
- 订阅、节点、控制端 secret、机场名称不入库。
- 使用 `mixed-port` 简化工具配置，HTTP / SOCKS 都统一指向 `127.0.0.1:7890`。

## Windows 系统代理和 WinHTTP

mihomo 开启系统代理后，浏览器和多数 GUI 会跟随 Windows 用户系统代理。

少数系统组件或服务读取 WinHTTP 代理，需要时手动同步：

```powershell
netsh winhttp import proxy source=ie
netsh winhttp show proxy
```

清理 WinHTTP 代理：

```powershell
netsh winhttp reset proxy
```

WinHTTP 影响范围比普通用户代理更大，本项目不建议脚本默认自动修改；只在明确需要时手工执行。

## PowerShell 临时代理函数

`windows/config/pwsh/profile.ps1` 提供临时代理开关：

```powershell
proxy-on
proxy-status
proxy-off
```

默认值：

```text
HTTP(S): http://127.0.0.1:7890
SOCKS:  socks5h://127.0.0.1:7890
```

这些函数只修改当前 PowerShell session 的环境变量，不写注册表、不改系统代理、不持久化。

## 不走系统代理的软件

按优先级处理：

1. 优先使用应用内代理，填 `127.0.0.1:7890`。
2. CLI / Electron 工具可用环境变量启动。
3. 仍不生效时，用 per-app 代理工具按进程转发。
4. 最后才临时启用 mihomo TUN。

TUN 不建议默认常开，因为它容易和 WSL、Docker、VPN、Tailscale、公司内网或局域网路由冲突。

## 开发工具分工

- Windows GUI 工具：优先系统代理。
- Windows PowerShell / CLI：优先 `proxy-on` 临时环境变量。
- VS Code 主进程：优先系统代理；不默认写死 `http.proxy`。
- VS Code Remote WSL extension host：按 WSL 内的环境变量处理，见 `wsl/docs/proxy.md`。
- Git / npm / pnpm / uv / pip / Docker 等主开发命令：优先放在 WSL 内处理。

## 边界

- 不提交 mihomo 订阅、节点、secret、日志、缓存。
- 不把代理地址写死进 Git / npm / pip 的全局配置，除非是本机手工设置。
- 不让代理配置成为安装层默认副作用；代理应是可开关、可恢复、可诊断的运行期配置。

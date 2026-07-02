# Windows 代理策略

本项目默认采用 **sing-box 用户态系统代理**：sing-box 监听 `127.0.0.1:7890`，写入当前用户的 Windows 系统代理；WSL mirrored 网络、浏览器和大多数 GUI 工具复用这个入口。mihomo 保留为备用核心。

TUN 不默认常开。只有应用内代理、系统代理和当前 shell 环境变量都覆盖不了时，才临时启用 TUN。

## 默认拓扑

```text
sing-box (127.0.0.1:7890, set_system_proxy)
  -> Windows 系统代理 / WinINET
  -> WSL mirrored + autoProxy + ./wsl/bootstrap.sh --proxy
  -> 少数软件单独配置应用内代理 / per-app proxy
  -> 临时 TUN 兜底
```

## 安装与发布

`proxy-core` 通过 winget 安装代理核心。sing-box、mihomo 和 WinSW 都是 winget 的 portable/archive 包，exe 会落在 `%LOCALAPPDATA%\Microsoft\WinGet\Packages\...`，因此统一用 publish 层复制到稳定路径：

| winget 包 | 固定路径 |
|---|---|
| `SagerNet.sing-box` | `C:\Tools\sing-box\sing-box.exe` |
| `MetaCubeX.Mihomo` | `C:\Tools\mihomo\mihomo.exe` |
| `CloudBees.WindowsServiceWrapper.3` | `C:\Tools\mihomo\mihomo-service.exe` |

```powershell
.\windows\bootstrap.ps1 -Profile proxy-core
.\windows\publish-tools.ps1 -Plan
.\windows\publish-tools.ps1
```

升级后也要重新 publish：

```powershell
winget upgrade SagerNet.sing-box
.\windows\publish-tools.ps1
```

## sing-box 配置

仓库模板：[windows/proxy/sing-box.example.json](../proxy/sing-box.example.json)

恢复到本机运行目录：

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\sing-box" | Out-Null
Copy-Item windows\proxy\sing-box.example.json "$env:USERPROFILE\sing-box\config.json"
```

至少替换这些私有值：

- `outbounds[].server`
- `outbounds[].uuid`
- `outbounds[].tls.server_name`
- `outbounds[].tls.reality.public_key`
- `outbounds[].tls.reality.short_id`

模板默认：

- mixed 入口：`127.0.0.1:7890`
- Clash API：`127.0.0.1:9090`
- Windows 用户系统代理：开启
- 内网域名先走内网 DNS，再直连
- 国内规则走本地 DNS，并按 `geosite-geolocation-cn` / `geoip-cn` 直连
- remote rule-set 启用 `experimental.cache_file` 后缓存在运行目录的 `cache.db`，不会落成可见的 `.srs` 文件

校验和运行：

```powershell
C:\Tools\sing-box\sing-box.exe check -c "$env:USERPROFILE\sing-box\config.json"
C:\Tools\sing-box\sing-box.exe run -D "$env:USERPROFILE\sing-box" -c "$env:USERPROFILE\sing-box\config.json"
```

## 用户级自启动

当前默认是用户级启动项，不用 Windows service。原因：模板使用 `set_system_proxy: true`，这是当前用户代理设置；作为 LocalSystem service 运行时容易改到 SYSTEM 用户而不是登录用户。

创建 Startup 快捷方式即可：

```powershell
$startup = [Environment]::GetFolderPath('Startup')
$shortcutPath = Join-Path $startup 'sing-box.lnk'
$exe = 'C:\Tools\sing-box\sing-box.exe'
$dir = "$env:USERPROFILE\sing-box"
$config = Join-Path $dir 'config.json'
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $exe
$shortcut.Arguments = "run -D `"$dir`" -c `"$config`""
$shortcut.WorkingDirectory = $dir
$shortcut.WindowStyle = 7
$shortcut.Description = 'Start sing-box proxy at user logon'
$shortcut.Save()
```

重启：

```powershell
C:\Tools\sing-box\sing-box.exe check -c "$env:USERPROFILE\sing-box\config.json"
Get-Process -Name sing-box -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Process C:\Tools\sing-box\sing-box.exe -ArgumentList 'run','-D',"$env:USERPROFILE\sing-box",'-c',"$env:USERPROFILE\sing-box\config.json" -WorkingDirectory "$env:USERPROFILE\sing-box" -WindowStyle Hidden
```

## PowerShell 临时代理

配置层的 PowerShell profile 提供当前 session 的代理环境变量开关：

```powershell
.\windows\configure.ps1 -Pwsh -Plan
.\windows\configure.ps1 -Pwsh
```

```powershell
proxy-on
proxy-status
proxy-off
proxy-test
```

这些函数只改当前 PowerShell 进程及其子进程，不写系统代理、WinHTTP、注册表或工具持久配置。

## WSL

WSL mirrored 网络下直接访问 Windows 本机 `127.0.0.1:7890`。新机恢复时先配置 Windows sing-box，再在 WSL 内执行：

```bash
./wsl/bootstrap.sh --proxy --plan
./wsl/bootstrap.sh --proxy
```

这会写 shell、apt、Git 和 Docker daemon 的代理运行期配置。详见 `wsl/docs/proxy.md`。

## mihomo 备用

mihomo 仍保留模板和 WinSW 服务锚点：

- [windows/proxy/config.example.yaml](../proxy/config.example.yaml)
- [windows/proxy/mihomo-service.example.xml](../proxy/mihomo-service.example.xml)

它适合需要 mihomo 规则生态或已有服务化配置的设备。不要让 mihomo TUN 和 sing-box TUN 同时常驻。

## 边界

- 不提交真实节点、订阅、dashboard secret、缓存或日志。
- 不把代理地址写死进 Git / npm / pip / Dockerfile / Compose 后提交。
- 默认用用户级 sing-box；service 只在 TUN 或非用户系统代理场景再做。

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

完整的脱敏示例配置见 `windows/proxy/config.example.yaml`：复制为 `config.yaml` 放进 mihomo 配置目录（Windows 默认 `%USERPROFILE%\.config\mihomo\`）。**默认主力是自建 VLESS（Vision + REALITY）节点**——填入节点私有值（`server` / `uuid` / `servername` / `public-key` 等）与本机 `secret` 即可跑起来。**订阅默认关闭、只作临时应急**：自建节点全挂时，再按文件内注释整段启用 `proxy-providers` + `EMERGENCY` 组，平时不依赖机场。`mihomo` 找不到配置时会自动生成一份只含监听骨架、无任何节点的默认配置，所以恢复时以本示例为准、不要依赖那份空壳默认。

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

这些函数来自**配置层**，不随装包自动出现。`windows\bootstrap.ps1`、`proxy-core` 等只装软件、不碰配置；要拿到下面的代理开关，需显式应用 PowerShell profile 模板：

```powershell
.\windows\configure.ps1 -Pwsh -Plan   # 先预览（会先备份现有 $PROFILE）
.\windows\configure.ps1 -Pwsh         # 应用
```

应用后 `windows/config/pwsh/profile.ps1` 提供临时代理开关：

```powershell
proxy-on
proxy-status
proxy-off
proxy-test
```

默认值：

```text
HTTP(S): http://127.0.0.1:7890
SOCKS:  socks5h://127.0.0.1:7890
```

这些函数只修改当前 PowerShell session 的环境变量，不写注册表、不改系统代理、不持久化。

`proxy-test` 做一次连通性 + 出口 IP 自检：

- 当前 shell 设了 `https_proxy`（即跑过 `proxy-on`）时，走该代理测试；
- 没设时，走 Windows 系统代理默认值测试。

它能区分“代理没起来”和“代理起来了但当前没选中它”，对应“可诊断”原则。

同一份 profile 还提供 `mihomo` 启动器。`proxy-core` 用 winget 装的 `MetaCubeX.Mihomo` 既不建 PATH shim、可执行文件名又是带平台后缀的 `mihomo-windows-amd64.exe`，所以直接敲 `mihomo` 会“找不到命令”。该函数优先用 `publish-tools.ps1` 落到 `C:\Tools\mihomo\mihomo.exe` 的固定路径（与 WinSW 服务同一个 exe），找不到时再回退到 winget 安装目录里动态定位，转发全部参数：

```powershell
mihomo -v                                    # 查看版本
mihomo -t -d "$env:USERPROFILE\.config\mihomo"   # 只校验配置后退出
mihomo -d "$env:USERPROFILE\.config\mihomo"      # 按配置目录运行
```

未应用配置层、或想绕过函数时，用 `C:\Tools\mihomo\mihomo.exe` 或 winget 安装目录里的完整路径运行同一个 exe 即可。

## 把便携内核落到 C:\Tools（publish-tools.ps1）

`MetaCubeX.Mihomo` 和 `CloudBees.WindowsServiceWrapper.3`（WinSW）都是 winget 的 **archive / portable** 包：没有安装器、没有开始菜单项、不建 PATH shim，exe 被解压到 `%LOCALAPPDATA%\Microsoft\WinGet\Packages\<Id>_<source>\` 这种带哈希后缀的目录里，名字还带平台后缀，确实“不太好找”。winget 仍负责下载与升级（`winget upgrade` 照常用），但 exe 留在那个埋得很深的目录里。

`windows\publish-tools.ps1` 在保留 winget 作为下载/升级来源的前提下，把解析到的 exe **复制**到一个可预期的工具根目录，落成稳定文件名。映射写在 `windows/manifests/tools-publish.json`（每个 `wingetId` 必须由某个 `winget-*.json` 真正安装，`validate.ps1` 会校验）：

| winget 包 | 落地路径（默认根 `C:\Tools`） |
|---|---|
| `MetaCubeX.Mihomo` | `C:\Tools\mihomo\mihomo.exe` |
| `CloudBees.WindowsServiceWrapper.3` | `C:\Tools\mihomo\mihomo-service.exe` |

```powershell
.\windows\bootstrap.ps1 -Profile proxy-core   # 先用 winget 装内核（下载到 WinGet\Packages）
.\windows\publish-tools.ps1 -Plan             # 预览要复制什么、备份什么
.\windows\publish-tools.ps1                    # 落地到 C:\Tools（覆盖前先 .bak 备份）
.\windows\publish-tools.ps1 -ToolsRoot D:\Tools  # 想换根目录就传 -ToolsRoot
```

特点与本仓库其余安装器一致：**plan-first**（`-Plan` 只打印不写盘）、**幂等**（按文件哈希比对，相同就跳过）、**覆盖前先备份**（时间戳 `.bak`）。

关键点：**升级后要重新 publish**。`winget upgrade MetaCubeX.Mihomo` 只更新埋在 `WinGet\Packages` 里的那份；`C:\Tools\mihomo\mihomo.exe`（也就是 WinSW 服务实际加载的 exe）不会自动跟着变。升级内核后再跑一次 `.\windows\publish-tools.ps1`，服务下次重启即用上新二进制——因为服务指向的是固定路径，不需要重新注册。

## mihomo 作为 Windows 服务（WinSW）

WinSW 把 mihomo 内核包装成开机自启的 Windows 服务。约定是把 WinSW 的 exe 重命名成 `mihomo-service.exe`、把服务定义放成同名的 `mihomo-service.xml` 与之并列（`publish-tools.ps1` 已经把 WinSW 落成 `C:\Tools\mihomo\mihomo-service.exe`）。

仓库里以 `windows/proxy/mihomo-service.example.xml` 作为**脱敏恢复锚点**（无任何密钥/订阅/身份），它指向 `C:\Tools\mihomo\mihomo.exe`，配置目录用 `-d C:\ProgramData\mihomo`、日志滚动到 `C:\ProgramData\mihomo\logs`。恢复时：

```powershell
# 1) 已经 winget 装好并 publish 到 C:\Tools\mihomo
# 2) 复制锚点为实际服务定义（按需改 -d 配置目录）
Copy-Item windows\proxy\mihomo-service.example.xml C:\Tools\mihomo\mihomo-service.xml

# 3) 注册并启动（需管理员）——这是设备相关的一次性手工动作
C:\Tools\mihomo\mihomo-service.exe install
C:\Tools\mihomo\mihomo-service.exe start
```

边界：注册服务需要管理员、属于设备相关状态，不写进脚本默认流程（见 `windows/docs/manual-boundaries.md`）。mihomo 的真实配置（订阅、节点、secret）留在 `-d` 指向的 `C:\ProgramData\mihomo`，以 `config.example.yaml` 为恢复基线，不入库。

## Web UI（web 端）

mihomo 自身不带面板，Web UI 是连接 `external-controller` 的独立前端。本项目推荐两种轻量方式，二选一：

1. **托管面板（最轻量，无需安装）**：直接用浏览器打开托管版仪表盘，例如 metacubexd / zashboard / yacd，填入：
   - API 地址：`http://127.0.0.1:9090`
   - secret：与 mihomo 配置里的 `secret` 一致

   托管页面是 https 来源访问本地 http 控制端，mihomo 需要放开 CORS：

   ```yaml
   external-controller: 127.0.0.1:9090
   secret: "replace-with-local-secret"
   external-controller-cors:
     allow-origins: ["*"]
     allow-private-network: true
   ```

2. **本地内置面板（离线可用）**：让 mihomo 自己托管前端，把面板静态文件放到本地目录：

   ```yaml
   external-controller: 127.0.0.1:9090
   secret: "replace-with-local-secret"
   external-ui: ui
   external-ui-name: metacubexd
   external-ui-url: "https://github.com/MetaCubeX/metacubexd/archive/refs/heads/gh-pages.zip"
   ```

   之后面板地址为 `http://127.0.0.1:9090/ui/`。

原则：

- 控制端只监听 `127.0.0.1:9090`，secret 必填，不留空、不入库。
- 选托管面板时只对本地控制端开 CORS；不开 `allow-lan`、不把控制端暴露到局域网。
- 面板订阅、节点、secret 都是设备本地运行期状态，不进仓库。

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

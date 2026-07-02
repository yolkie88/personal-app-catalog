# 手工边界

这些内容可以属于个人应用目录，但不应进入默认自动恢复，也不应提交真实配置。

## 敏感排除

| 内容 | 处理 |
|---|---|
| 代理订阅、节点、dashboard secret | 不入库 |
| SSH 私钥、GPG 私钥、token | 不入库 |
| 远控设备码、无人值守密码、授权文件 | 不入库 |
| 软件许可证、序列号、Typora 授权信息 | 不入库 |
| 备份仓库密码、keyfile、恢复密钥 | 不入库 |
| 游戏本体、存档、Mod | 不入库 |
| 授权风险工具 | 不入库 |

## 配置层

`windows/config/` 下的工具配置模板（PowerShell profile/模块、Windows Terminal defaults、Git 共享配置）是脱敏模板，由 `.\windows\configure.ps1` 应用，覆盖前先备份。详见 `config.md`。

Git 身份（`user.name` / `user.email`）、SSH/GPG、各类账号登录、PowerShell 历史等仍按本文件其余部分手工恢复，不进入仓库。

## 代理核心

`proxy-core` 安装 sing-box、Mihomo 和 WinSW。sing-box 是默认用户态系统代理核心；mihomo 作为备用核心和服务化候选。winget 只负责下载/升级 portable 包，再由 `publish-tools.ps1` 落到 `C:\Tools\...`。真实配置按设备维护，TUN 只按设备、按需开启。

建议边界：

- 已提交脱敏模板 `windows/proxy/sing-box.example.json`；复制为本机 `config.json` 后填入节点私有值。
- 已保留 mihomo 脱敏模板 `windows/proxy/config.example.yaml`；备用时复制为 `config.yaml` 后填入订阅、`secret` 等私有值。
- 不提交订阅、节点、secret、缓存、真实日志。
- 不让多个 TUN 核心同时常驻。
- 服务化路径、账号和权限按设备处理。

Mihomo TUN 参考基线：

- `tun.enable: true`
- `tun.stack: mixed`
- `tun.auto-route: true`
- `tun.auto-detect-interface: true`
- `tun.dns-hijack: [any:53, tcp://any:53]`
- `tun.strict-route: true`

sing-box TUN 参考基线：

- inbound 使用 `type: tun`
- 开启 `auto_route`
- 开启 `strict_route`
- 明确 DNS 和 route rule

## 网络和远控

| 类型 | 目录策略 |
|---|---|
| Tailscale | 通过 `network` profile 安装，账号和设备授权手工恢复 |
| WinSCP | 通过 `network` profile 安装，站点密码不入库 |
| RustDesk / ToDesk | 远控工具只保留一个主来源，设备授权手工恢复 |
| Karing / Clash Verge / v2rayN | 只作调试或订阅转换，不作为主恢复路径 |

## 硬件和系统工具

| 类型 | 目录策略 |
|---|---|
| GPU 驱动 / NVIDIA App | 官网、Windows Update 或厂商工具，按设备恢复 |
| 厂商管家 | Store/厂商官网，按设备品牌恢复 |
| 外设配置 | winget 或厂商官网，按外设恢复 |
| 超频/监控 | 手工/便携，只在需要调校的设备恢复 |
| 硬件检测 | winget/便携，维修或验机设备恢复 |
| 启动盘工具 | winget/便携，装机维护设备恢复 |
| 系统维护 | 便携优先，临时使用 |

## 便携应用

适合便携维护：

- 硬件检测和维修工具箱
- 系统维护和启动盘工具
- 代理、网络调试、抓包临时工具
- 固定版本的厂商工具
- 授权敏感工具
- 单次任务工具或不希望常驻 PATH 的工具

不适合便携重复维护：

- Git
- VS Code
- Python
- Node.js
- PotPlayer
- MediaInfo
- Typora

这些已有主来源，应优先跟随 manifest。

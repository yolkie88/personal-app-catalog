# macOS 手工边界

这些内容可以属于个人恢复流程，但不应自动安装、自动配置或提交真实值。

## 敏感排除

| 内容 | 处理 |
|---|---|
| Apple ID、iCloud、App Store 登录 | 手工恢复 |
| SSH/GPG 私钥、API keys、tokens | 不入库 |
| 代理订阅、节点、dashboard secret、证书 | 不入库 |
| Tailscale 设备授权、tailnet 策略 | 手工恢复 |
| RustDesk 设备码、无人值守密码 | 不入库 |
| Kopia/restic/rclone 仓库密码、keyfile、远端凭据 | 不入库 |
| Typora、BetterDisplay、PopClip、Proxyman 等授权 | 手工恢复 |
| Raycast、VS Code、ChatGPT、Claude、Cherry Studio、ChatWise 登录 | 手工恢复 |
| Codex App 安装渠道和登录状态 | 手工恢复 |
| Ollama/LM Studio/Jan 模型和对话历史 | 不入库 |
| Docker/OrbStack VM、镜像、volume | 不入库 |
| Android SDK、模拟器、IDE 登录和插件状态 | 手工恢复 |

## 已安装但不自动恢复的应用

| 应用 | 原因 | 策略 |
|---|---|---|
| Bob | Homebrew cask 已弃用，转向 Mac App Store | 作为翻译候选，暂不自动安装 |
| Shadowrocket | 付费 App Store / 代理配置敏感 | 手工安装和配置 |
| APTV / Infuse / SenPlayer / MediaCenter | 媒体库、订阅和 App Store 状态绑定 | 手工恢复 |
| iMenu / 小米互联服务 | App Store/厂商账号和设备生态绑定 | 手工恢复 |
| Sniffnet | 当前 Homebrew cask 不可用 | 需要时从官方 release 手工安装 |
| AnyGo | 授权和用途强设备化 | 手工恢复 |
| Otty / Hermes | 来源或维护状态不适合作为恢复默认项 | 暂不纳入 |
| IntelliJ IDEA | 商业授权和插件状态复杂 | 需要时单独 profile 或手工安装 |
| NeteaseMusic | 娱乐账号和版权区域绑定 | 手工恢复 |

## 权限和系统设置

很多 mac 工具安装后仍需要手工授权：

- Accessibility：Rectangle、AltTab、LinearMouse、Mos、OnlySwitch、PixPin、PopClip；
- Screen Recording：PixPin、远控和会议工具；
- Network Extension / VPN：Tailscale、LuLu、代理工具；
- Full Disk Access：备份工具、终端、开发工具按需授予；
- Login Items：只给长期需要常驻的工具开启。

这些权限由 macOS TCC 管理，不建议脚本化，也不应提交导出状态。

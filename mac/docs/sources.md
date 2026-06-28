# macOS 来源策略

macOS 侧优先使用 Homebrew 和 Homebrew Cask。Mac App Store、官方安装器、GitHub Releases 和厂商同步工具可以记录，但不默认伪装成可自动恢复项。

## 来源优先级

| 来源 | 适合内容 | 是否自动恢复 | 记录位置 |
|---|---|---|---|
| Homebrew formula | CLI、服务端组件、开发工具 | 是 | `mac/manifests/Brewfile-*` |
| Homebrew cask | 常规 GUI、字体、桌面工具 | 是 | `mac/manifests/Brewfile-*` |
| mise | Node/Python/K8s 等开发运行时 | 是 | `mac/packages/mise-*.txt` |
| Mac App Store | Apple 官方 App、付费/订阅 App、区域绑定 App | 暂不默认自动恢复 | `manual-boundaries.md` |
| 官方安装器 | 商业软件、厂商生态、特殊驱动 | 通常否 | 文档记录 |
| GitHub Releases | 小众开源工具、Homebrew 未收录工具 | 通常否 | 文档记录 |
| brew services | 长期运行服务 | 只记录，不自动启用 | `packages/services-home-hub.txt` |

## 记录规则

- 同一应用只保留一个主来源。
- Homebrew cask 可用时优先用 cask；App Store 版只在 cask 不可用或 Store 版明显更合适时记录。
- 付费、订阅、授权、账号和区域绑定强的应用不进入默认层。
- 服务只安装二进制，真实配置和 launch state 手工恢复。
- `brew bundle dump` 只能作为盘点输入，不能原样提交。

## 当前选择说明

- OrbStack 作为 macOS 容器主方案：虽然不是开源，但 mac 体验和资源占用优于 Docker Desktop，且本机已安装。Colima 作为开源替代暂不自动安装，避免双运行时。
- BetterDisplay 保留：Mac mini 外接显示器场景价值高；授权和具体显示布局手工恢复。
- LinearMouse + Mos 保留：本机有外接鼠标使用痕迹，优先开源免费工具改善滚动和加速度。
- LuLu 保留：Objective-See 的开源防火墙，适合安全可见性；规则手工恢复。
- Bob 暂不自动化：Homebrew cask 已弃用，Mac App Store 恢复依赖账号状态。
- Sniffnet 暂不自动化：本机已安装，但 Homebrew cask 不可用；需要时手工安装。


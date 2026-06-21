# 来源策略

个人应用目录不限于 winget。关键是每个条目必须说明主来源、是否可自动恢复、配置是否可以入库。

## 来源优先级

| 来源 | 适合内容 | 是否自动恢复 | 记录位置 |
|---|---|---|---|
| winget | 常规桌面应用、稳定 GUI、常规 CLI | 是 | `windows/manifests/winget-*.json` |
| Scoop | CLI、小型开发工具、便携命令 | 是 | `windows/manifests/scoop-*.txt` |
| Microsoft Store | Store 优先应用、系统集成应用 | 部分 | manifest 或文档 |
| GitHub Releases | 小众开源工具、单文件工具、未进入包管理器的软件 | 通常否 | 文档记录 repo/release |
| 官方安装器 | 商业软件、厂商工具、远控、驱动 | 通常否 | 文档记录官网和配置边界 |
| 语言包管理器 | `npm`, `pnpm`, `uv`, `pipx`, `cargo`, `go install`, `.NET tool` | 部分 | 后续独立清单 |
| Docker / WSL | 数据库、服务端组件、Linux 工具链 | 否 | compose、发行版、恢复步骤 |
| 手工/便携 | 维修、调试、固定版本、授权敏感工具 | 否 | `manual-boundaries.md` |

## 记录规则

- 自动安装项必须来源稳定、重复安装风险低、无敏感配置。
- 账号、授权、订阅、节点、私钥、设备码和备份密钥只记录恢复边界，不记录真实值。
- GitHub/官方安装器来源可以成为目录的一部分，但不能伪装成可自动恢复项。
- 同一应用只保留一个主来源，替代来源只写备注。
- 某台设备的软件快照只是目录维护输入，不直接等同于个人应用目录。

## 非 winget 候选池

| 类型 | 候选 | 策略 |
|---|---|---|
| 快捷启动/自动化 | Quicker, uTools, Listary | 配置和账号绑定强，先手工记录 |
| 翻译 | STranslate, Pot | `Pot` 可走 winget；STranslate 记录官方/GitHub 来源 |
| 本地图像/AI 工作流 | ComfyUI Desktop 等 | 体积和数据目录大，记录手工恢复策略 |
| 重型开发 | Visual Studio Build Tools, VMware, Android Studio | 官方安装器和组件选择复杂，走手工文档 |
| 硬件维修 | 图吧工具箱, Dism++, GPU-Z, CPU-Z, OCCT | 便携优先，按设备角色恢复 |

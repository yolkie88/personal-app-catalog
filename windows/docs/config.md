# Windows 工具配置层

本文件说明 `windows/config/` 下的工具配置模板和 `windows/configure.ps1` 应用脚本。

这些模板是**脱敏模板**，只包含跨设备通用的优化配置，不含身份信息、凭据或密钥。身份（`user.name` / `user.email`）、SSH/GPG、各类账号登录仍按 `manual-boundaries.md` 手工恢复。

## 应用方式

`windows\configure.ps1` 把模板应用到对应位置；先用 `-Plan` 预览：

```powershell
.\windows\configure.ps1 -All -Plan     # 只打印将要变更的内容
.\windows\configure.ps1 -All            # 应用全部
.\windows\configure.ps1 -Pwsh           # 仅 PowerShell
.\windows\configure.ps1 -Terminal       # 仅 Windows Terminal
.\windows\configure.ps1 -Git            # 仅 Git 共享配置
.\windows\configure.ps1 -VSCode         # 仅 VS Code 扩展与设置
.\windows\configure.ps1 -Wsl            # 仅写 %USERPROFILE%\.wslconfig（mirrored 网络）
```

行为：

- 幂等。模块已安装则跳过；目标文件内容一致则跳过。
- 覆盖前先备份。已存在的目标文件会被复制为 `<file>.bak.<时间戳>`。
- PowerShell profile 不覆盖你已有的 `$PROFILE`，而是把托管 profile 拷为 `catalog.profile.ps1`，并在 `$PROFILE` 中追加一行带标记的 dot-source。
- Windows Terminal 设置采用深合并，保留你已有的 profiles，只覆盖 defaults（字体、配色等）。
- `.wslconfig` 是 INI，无法深合并，采用**整文件写入**（已存在的先备份为 `.bak`）。若你原来有设备级 `memory`/`processors`/`swap` 等设置，从备份里挪回。改完执行 `wsl --shutdown` 才生效。

## 模板清单

| 模板 | 应用目标 | 作用 |
|---|---|---|
| `config/pwsh/modules.txt` | `Install-Module -Scope CurrentUser` | 模块清单：PSReadLine、posh-git、Terminal-Icons、PSFzf |
| `config/pwsh/profile.ps1` | `catalog.profile.ps1`（由 `$PROFILE` dot-source） | PSReadLine 历史预测、模块按存在与否加载、starship、PSFzf 键位、常用 alias、当前 session 代理开关 |
| `config/terminal/settings.defaults.json` | Windows Terminal `settings.json`（深合并） | 默认字体、配色、padding 等 defaults |
| `config/git/gitconfig.shared` | `~\catalog.gitconfig`（通过 `include.path` 引入） | 常用 alias、合理默认值（merge/diff/pull/push/init/rebase；不含身份，无外部依赖） |
| `config/git/gitconfig.delta` | `~\catalog-delta.gitconfig`（仅在检测到 delta 时通过 `include.path` 引入） | delta pager 与 diff filter 设置 |
| `config/vscode/extensions.txt` | `code --install-extension`（逐个，已装则跳过） | 推荐扩展清单：Remote/Containers、K8s、Python、TS/Vue、Java/Spring Boot、YAML/TOML/Markdown、Git、Jupyter、项目管理、中文语言包 |
| `config/vscode/settings.json` | VS Code 用户 `settings.json`（深合并） | formatOnSave、各语言默认 formatter、关闭遥测、允许中文文档非 ASCII 等（不含账号/Sync 密钥/token） |
| `config/wsl/wslconfig` | `%USERPROFILE%\.wslconfig`（整文件写入，先备份） | WSL2 全局网络：mirrored networking、dnsTunneling、autoProxy、firewall；设备级资源上限（memory/processors/swap）以注释示例给出 |

## 代理

Windows 代理策略见 `windows/docs/proxy.md`。本项目推荐 sing-box 用户态系统代理：系统代理优先，WinHTTP 按需同步，少数不走系统代理的软件单独处理，TUN 仅兜底。

PowerShell profile 提供当前 session 的代理开关：

```powershell
proxy-on
proxy-status
proxy-off
```

这些函数只修改当前 PowerShell 进程和子进程的代理环境变量，不改 Windows 系统代理、WinHTTP 或注册表。

## 依赖闭环

`delta` / `fzf` / `starship` / `lazygit` / `bat` 在 Windows 只存在于 `scoop-cli.txt`（需 `-WithScoop` 才装），不在默认 winget 层。因此：

- Git 的 delta pager 拆到独立的 `gitconfig.delta`，`configure.ps1 -Git` 只在检测到 `delta` 时才通过 `include.path` 引入它；否则 Git 用默认 pager，不会因缺 delta 而报错。
- PowerShell profile 对 starship/PSFzf/bat/lazygit 都做了存在性判断，缺失时只是不生效。
- `configure.ps1` 结束时会列出未找到的可选工具，并提示用 `.\windows\bootstrap.ps1 -WithScoop` 安装（仅提示，不自动安装）。

## 边界

- 模板不含身份、凭据、密钥或 token；`windows/validate.ps1` 会扫描 `windows/config/` 拦截 secret 赋值和 email。
- Git 身份仍写在你自己的全局配置；本层只通过 `include.path` 叠加共享配置。
- 配置层不是 winget profile，不进入 `bootstrap.ps1` 的 `ValidateSet`、`all` 集合或 `catalog.md` 的 profile 表。
- JSON 模板（Windows Terminal、VS Code settings）里以 `_` 开头的 key 是模板元数据（如 `_comment`），`configure.ps1` 深合并前会剥掉，不会写进你的真实配置。
- VS Code 配置层是可选的（`configure.ps1 -VSCode`）：只管理推荐扩展和脱敏 settings 默认值，深合并保留你已有的 key。**不管理**账号登录、Settings Sync 密钥、私有扩展源——这些仍走 VS Code 自带 Settings Sync 或手工恢复。
- 代理模板只提供本机默认地址和临时开关；sing-box/mihomo 的节点、订阅、控制端 secret、日志和缓存不入库。

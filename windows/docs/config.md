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
```

行为：

- 幂等。模块已安装则跳过；目标文件内容一致则跳过。
- 覆盖前先备份。已存在的目标文件会被复制为 `<file>.bak.<时间戳>`。
- PowerShell profile 不覆盖你已有的 `$PROFILE`，而是把托管 profile 拷为 `catalog.profile.ps1`，并在 `$PROFILE` 中追加一行带标记的 dot-source。
- Windows Terminal 设置采用深合并，保留你已有的 profiles，只覆盖 defaults（字体、配色等）。

## 模板清单

| 模板 | 应用目标 | 作用 |
|---|---|---|
| `config/pwsh/modules.txt` | `Install-Module -Scope CurrentUser` | 模块清单：PSReadLine、posh-git、Terminal-Icons、PSFzf |
| `config/pwsh/profile.ps1` | `catalog.profile.ps1`（由 `$PROFILE` dot-source） | PSReadLine 历史预测、模块按存在与否加载、starship、PSFzf 键位、常用 alias |
| `config/terminal/settings.defaults.json` | Windows Terminal `settings.json`（深合并） | 默认字体、配色、padding 等 defaults |
| `config/git/gitconfig.shared` | `~\catalog.gitconfig`（通过 `include.path` 引入） | 常用 alias、合理默认值（merge/diff/pull/push/init/rebase；不含身份，无外部依赖） |
| `config/git/gitconfig.delta` | `~\catalog-delta.gitconfig`（仅在检测到 delta 时通过 `include.path` 引入） | delta pager 与 diff filter 设置 |
| `config/vscode/extensions.txt` | `code --install-extension`（逐个，已装则跳过） | 推荐扩展清单：WSL Remote、Docker、K8s、Python、TS/Vue、Java、YAML、Markdown、GitLens、GitHub Actions、REST Client |
| `config/vscode/settings.json` | VS Code 用户 `settings.json`（深合并） | formatOnSave、各语言默认 formatter、关闭遥测等（不含账号/Sync 密钥/token） |

## 依赖闭环

`delta` / `fzf` / `starship` / `lazygit` / `bat` 在 Windows 只存在于 `scoop-cli.txt`（需 `-WithScoop` 才装），不在默认 winget 层。因此：

- Git 的 delta pager 拆到独立的 `gitconfig.delta`，`configure.ps1 -Git` 只在检测到 `delta` 时才通过 `include.path` 引入它；否则 Git 用默认 pager，不会因缺 delta 而报错。
- PowerShell profile 对 starship/PSFzf/bat/lazygit 都做了存在性判断，缺失时只是不生效。
- `configure.ps1` 结束时会列出未找到的可选工具，并提示用 `.\windows\bootstrap.ps1 -WithScoop` 安装（仅提示，不自动安装）。

## 边界

- 模板不含身份、凭据、密钥或 token；`windows/validate.ps1` 会扫描 `windows/config/` 拦截 secret 赋值和 email。
- Git 身份仍写在你自己的全局配置；本层只通过 `include.path` 叠加共享配置。
- 配置层不是 winget profile，不进入 `bootstrap.ps1` 的 `ValidateSet`、`all` 集合或 `catalog.md` 的 profile 表。
- VS Code 配置层是可选的（`configure.ps1 -VSCode`）：只管理推荐扩展和脱敏 settings 默认值，深合并保留你已有的 key。**不管理**账号登录、Settings Sync 密钥、私有扩展源——这些仍走 VS Code 自带 Settings Sync 或手工恢复。

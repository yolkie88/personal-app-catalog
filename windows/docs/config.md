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
| `config/git/gitconfig.shared` | `~\catalog.gitconfig`（通过 `include.path` 引入） | delta pager、常用 alias、合理默认值（不含身份） |

## 边界

- 模板不含身份、凭据、密钥或 token；`windows/validate.ps1` 会扫描 `windows/config/` 拦截 secret 赋值和 email。
- Git 身份仍写在你自己的全局配置；本层只通过 `include.path` 叠加共享配置。
- 配置层不是 winget profile，不进入 `bootstrap.ps1` 的 `ValidateSet`、`all` 集合或 `catalog.md` 的 profile 表。
- VS Code 配置不在本层管理，使用 VS Code 自带 Settings Sync。

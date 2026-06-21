# personal-app-catalog

个人应用清单中心，附带 Windows 恢复脚本。

这个仓库维护的是“我长期认可、愿意跨设备恢复的应用目录”，不是某台电脑的软件盘点。能自动安装的内容放在 `windows/manifests/`，不能或不应该自动恢复的内容写入文档的手工边界。

## 快速使用

先做结构校验和安装预览：

```powershell
cd <repo-path>
Set-ExecutionPolicy -Scope Process Bypass
.\windows\validate.ps1
.\windows\bootstrap.ps1 -Plan -Report
```

确认后安装默认层：

```powershell
.\windows\bootstrap.ps1 -Report
```

默认只安装 `core + agentic-dev`。AI 编程工具主线只保留 Codex 和 Claude。

常用显式 profile：

```powershell
.\windows\bootstrap.ps1 -Profile daily -Report
.\windows\bootstrap.ps1 -Profile daily-extra -Report
.\windows\bootstrap.ps1 -Profile backup -Report
.\windows\bootstrap.ps1 -Profile backup-cli -Report
.\windows\bootstrap.ps1 -Profile network -Report
.\windows\bootstrap.ps1 -Profile automation -Report
.\windows\bootstrap.ps1 -Profile communication -Report
.\windows\bootstrap.ps1 -Profile dev-extra -Report
.\windows\bootstrap.ps1 -Profile k8s-toolkit -Report
.\windows\bootstrap.ps1 -Profile maintenance -Report
.\windows\bootstrap.ps1 -Profile desktop-enhance -Report
.\windows\bootstrap.ps1 -Profile media -Report
.\windows\bootstrap.ps1 -Profile media-toolkit -Report
.\windows\bootstrap.ps1 -Profile gaming -Report
.\windows\bootstrap.ps1 -Profile sync-storage -Report
.\windows\bootstrap.ps1 -Profile security-toolkit -Report
.\windows\bootstrap.ps1 -Profile creative -Report
.\windows\bootstrap.ps1 -Profile local-ai -Report
.\windows\bootstrap.ps1 -Profile proxy-core -Report
.\windows\bootstrap.ps1 -WithScoop -Report
```

组合安装前建议先预览：

```powershell
.\windows\bootstrap.ps1 -Profile daily,network,automation,dev-extra,k8s-toolkit -WithScoop -Plan -Report
```

更新和快照：

```powershell
.\windows\update.ps1
.\windows\update.ps1 -All -IncludeScoop
.\windows\export.ps1
```

## 文档

| 文档 | 用途 |
|---|---|
| `windows/docs/catalog.md` | 当前 profile 和应用目录 |
| `windows/docs/apps.md` | 每个软件的用途、保留理由和恢复边界 |
| `windows/docs/sources.md` | 来源优先级和非 winget 记录方式 |
| `windows/docs/manual-boundaries.md` | 敏感、授权、硬件、代理、远控等手工边界 |
| `windows/docs/operations.md` | 安装、更新、维护流程 |
| `windows/docs/recovery-playbook.md` | 新设备恢复顺序和人工边界 |

## 目录规则

- 默认层保持小，只包含 `core` 和 `agentic-dev`。
- AI 编程工具主线只保留 Codex 和 Claude，Copilot 不进入个人恢复目录。
- Python 通过 Python Install Manager 恢复，不在本仓库锁定某个 CPython 小版本。
- 播放器默认 PotPlayer。
- `all` 不是完整个人环境，只是宽松集合；敏感、强设备角色、大体积或维护类 profile 必须显式安装。
- 同一应用只保留一个主来源。
- Store、GitHub Releases、官方安装器、语言包管理器、Docker/WSL 和便携应用可以进入目录，但要明确是否可自动恢复。
- 订阅、节点、授权码、设备码、私钥、token、备份密钥和模型数据不进入 Git。
- 提交前运行 `windows/validate.ps1`；恢复前优先使用 `-Plan -Report` 确认将要执行的安装。

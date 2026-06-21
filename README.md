# personal-app-catalog

个人应用清单中心，附带 Windows 恢复脚本。

这个仓库维护的是“我长期认可、愿意跨设备恢复的应用目录”，不是某台电脑的软件盘点。能自动安装的内容放在 `windows/manifests/`，不能或不应该自动恢复的内容写入文档的手工边界。

## 快速使用

```powershell
cd <repo-path>
Set-ExecutionPolicy -Scope Process Bypass
.\windows\bootstrap.ps1
```

默认只安装 `core + agentic-dev`。

常用显式 profile：

```powershell
.\windows\bootstrap.ps1 -Profile daily
.\windows\bootstrap.ps1 -Profile backup
.\windows\bootstrap.ps1 -Profile network
.\windows\bootstrap.ps1 -Profile automation
.\windows\bootstrap.ps1 -Profile communication
.\windows\bootstrap.ps1 -Profile dev-extra
.\windows\bootstrap.ps1 -Profile desktop-enhance
.\windows\bootstrap.ps1 -Profile media
.\windows\bootstrap.ps1 -Profile media-toolkit
.\windows\bootstrap.ps1 -Profile gaming
.\windows\bootstrap.ps1 -Profile local-ai
.\windows\bootstrap.ps1 -Profile proxy-core
.\windows\bootstrap.ps1 -WithScoop
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
| `windows/docs/sources.md` | 来源优先级和非 winget 记录方式 |
| `windows/docs/manual-boundaries.md` | 敏感、授权、硬件、代理、远控等手工边界 |
| `windows/docs/operations.md` | 安装、更新、维护流程 |

## 目录规则

- 默认层保持小，只包含 `core` 和 `agentic-dev`。
- Python 通过 Python Install Manager 恢复，不在本仓库锁定某个 CPython 小版本。
- 播放器默认 PotPlayer。
- `all` 不是完整个人环境，只是宽松集合；敏感或强设备角色 profile 必须显式安装。
- 同一应用只保留一个主来源。
- Store、GitHub Releases、官方安装器、语言包管理器、Docker/WSL 和便携应用可以进入目录，但要明确是否可自动恢复。
- 订阅、节点、授权码、设备码、私钥、token、备份密钥和模型数据不进入 Git。

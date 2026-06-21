# 操作流程

## 安装

默认层：

```powershell
.\windows\bootstrap.ps1
```

显式 profile：

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
```

Scoop CLI：

```powershell
.\windows\bootstrap.ps1 -WithScoop
```

组合安装：

```powershell
.\windows\bootstrap.ps1 -Profile daily,network,automation -WithScoop
```

## 更新

只读查看：

```powershell
.\windows\update.ps1
```

执行更新：

```powershell
.\windows\update.ps1 -All
```

包含 Scoop：

```powershell
.\windows\update.ps1 -All -IncludeScoop
```

代理核心、远控、硬件调校、驱动、授权软件不要盲目跟随批量更新。

## 导出设备快照

```powershell
.\windows\export.ps1
```

导出的快照只作为目录维护输入，不直接等同于个人应用目录。

## 维护流程

1. 新软件先判断来源类型：winget、Scoop、Store、GitHub、官方安装器、语言包管理器、Docker/WSL、便携。
2. 判断是否可自动恢复。
3. 判断是否有账号、授权、私钥、订阅、设备码、备份密钥等敏感配置。
4. 如果可自动恢复，放入合适 profile。
5. 如果不可自动恢复，写入 `sources.md` 或 `manual-boundaries.md`。
6. 如果只是尝鲜，不进入 manifest。

## Git 初始化

确认没有敏感信息后再提交：

```powershell
git status
git add .gitignore README.md windows
git commit -m "init application catalog"
```

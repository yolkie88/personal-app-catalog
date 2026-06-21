# 操作流程

## 校验

提交前或恢复前先运行：

```powershell
.\windows\validate.ps1
```

校验内容包括：

- `bootstrap.ps1` 支持的 profile 和 `windows/manifests/winget-*.json` 是否对应；
- winget manifest 是否是合法 JSON，且包含 `PackageIdentifier`；
- 不同 manifest 中是否有重复包；
- README 和 `catalog.md` 中的 profile 名是否能被 bootstrap 接受；
- `scoop-cli.txt` 是否存在且包含有效包；
- `.gitignore` 是否包含导出、报告和关键本地数据的忽略规则。

## 预览

恢复新设备前建议先预览：

```powershell
.\windows\bootstrap.ps1 -Plan -Report
```

`-Plan` 只展示将要安装的 profile 和包，不执行安装。`-Report` 会生成 `windows/reports/bootstrap-report-*.json` 和 `windows/reports/bootstrap-report-*.txt`。

组合 profile 也建议先预览：

```powershell
.\windows\bootstrap.ps1 -Profile daily,network,automation,dev-extra,k8s-toolkit -WithScoop -Plan -Report
```

## 安装

默认层：

```powershell
.\windows\bootstrap.ps1 -Report
```

显式 profile：

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
```

Scoop CLI：

```powershell
.\windows\bootstrap.ps1 -WithScoop -Report
```

组合安装：

```powershell
.\windows\bootstrap.ps1 -Profile daily,network,automation,dev-extra,k8s-toolkit -WithScoop -Report
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
3. 判断是否涉及账号、授权、设备绑定或本地专属配置。
4. 如果可自动恢复，放入合适 profile。
5. 如果不可自动恢复，写入 `sources.md` 或 `manual-boundaries.md`。
6. 如果只是尝鲜，不进入 manifest。
7. 修改完成后执行 `windows/validate.ps1`。

## Git 初始化

确认本地生成文件没有进入暂存区后再提交：

```powershell
git status
git add .gitignore README.md .github windows
git commit -m "init application catalog"
```

# macOS 操作流程

## 校验

```bash
bash mac/validate.sh
```

校验内容包括：

- `bootstrap.sh` 的 profile 和 `mac/manifests/Brewfile-*` 是否一一对应；
- Brewfile 行格式是否只包含 `brew`、`cask`、`tap`；
- 不同 Brewfile 是否重复安装同一个 formula/cask；
- `all` 集合是否和 `mac/docs/catalog.md` 一致；
- mise 清单是否都带 `@` 版本选择器；
- 家庭枢纽服务清单格式是否有效；
- `mac/config/` 是否包含 secret-like assignment 或 email；
- `.gitignore` 是否放行需要跟踪的配置模板并忽略报告/导出。

## 安装预览

默认层：

```bash
./mac/bootstrap.sh --plan
```

显式 profile：

```bash
./mac/bootstrap.sh --profile home-hub --plan
./mac/bootstrap.sh --profile daily,desktop-enhance,home-hub --plan
```

mise 工具链：

```bash
./mac/bootstrap.sh --no-profiles --cli --k8s --plan
```

## 安装

默认层：

```bash
./mac/bootstrap.sh
```

Mac mini 家庭枢纽常用组合：

```bash
./mac/bootstrap.sh --profile default,daily,desktop-enhance,home-hub --cli --k8s
```

宽松集合：

```bash
./mac/bootstrap.sh --all --plan
./mac/bootstrap.sh --all
```

## 配置层

```bash
./mac/configure.sh --all --plan
./mac/configure.sh --all
```

`--plan` 不写入 `$HOME`；实际应用会先备份已有目标文件。

## 更新

Homebrew：

```bash
brew update
brew upgrade
brew upgrade --cask
```

mise：

```bash
mise upgrade
```

App Store 应用使用 App Store 或 `mas` 手工处理。付费、订阅、代理、备份、远控和家庭服务类应用不要盲目批量升级；升级前确认配置备份和回滚方式。

## 快照输入

本机已安装软件可以作为维护输入，但不能直接当作目录：

```bash
brew leaves
brew list --cask
find /Applications "$HOME/Applications" -maxdepth 1 -type d -name '*.app' -print
```

整理后只把长期认可、来源稳定、可重复安装的条目加入 manifest；账号、授权和运行态写入边界文档。


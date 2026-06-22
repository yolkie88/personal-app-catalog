# WSL 工具配置层

本文件说明 `wsl/config/` 下的工具配置模板：它们做什么、如何应用、备份行为，以及边界。

这些模板是**脱敏模板**，只包含跨设备通用的优化配置，不含身份信息、凭据、密钥或个人历史。身份（`user.name` / `user.email`）、SSH/GPG、kubeconfig 和所有 secret 仍按 `wsl-boundaries.md` 手工恢复。

## 应用方式

`wsl/bootstrap.sh --config` 把模板拷贝到对应位置；先用 `--plan` 预览：

```bash
./wsl/bootstrap.sh --config --plan   # 只打印将要拷贝/备份的内容
./wsl/bootstrap.sh --config          # 实际应用
```

行为：

- 幂等。目标文件内容与模板一致时跳过。
- 覆盖前先备份。已存在且内容不同的目标文件会被移动为 `<file>.bak.<时间戳>`。
- bash 别名通过 `~/.bashrc` 中一个带标记的 guarded 块 `source` 引入，重复运行不会重复写入。

## 模板清单

| 模板 | 目标路径 | 作用 |
|---|---|---|
| `config/nvim/init.lua` | `~/.config/nvim/init.lua` | 引导 `lazy.nvim`，安装一组精选插件（treesitter、telescope、mason/lspconfig、gitsigns、lualine、which-key、comment、autopairs、tokyonight），首次启动 `nvim` 时自动安装 |
| `config/starship/starship.toml` | `~/.config/starship.toml` | 统一 shell prompt：目录、git、node/python 版本、kubernetes context、命令耗时 |
| `config/tmux/tmux.conf` | `~/.tmux.conf` | 鼠标、256 色、vi 复制模式、直观分屏、vi 风格 pane 导航 |
| `config/bat/config` | `~/.config/bat/config` | bat 主题和显示风格 |
| `config/lazygit/config.yml` | `~/.config/lazygit/config.yml` | lazygit 界面与 delta 集成 |
| `config/git/gitconfig.shared` | `~/.config/git/catalog.gitconfig` | 通过 `include.path` 引入的共享 Git 配置：delta pager、常用 alias、合理默认值（不含身份） |
| `config/bash/aliases.sh` | `~/.config/personal-app-catalog/aliases.sh` | 常用 alias（`ll`、`gs`、`lg` 等），从 `.bashrc` guarded 块 source |

## 边界

- 模板不含身份、凭据、密钥、token 或个人历史；`wsl/validate.sh` 会扫描 `wsl/config/` 拦截 secret 赋值和 email。
- Git 身份仍写在你自己的 `~/.gitconfig`；本层只通过 `include.path` 叠加共享配置。
- neovim 插件锁文件（`lazy-lock.json`）、zoxide 历史、tmux session、shell 历史等运行期状态按设备生成，不入库。

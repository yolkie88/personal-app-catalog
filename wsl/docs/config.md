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
| `config/nvim/init.lua` | `~/.config/nvim/init.lua` | 引导 `lazy.nvim`，安装一组精选插件，首次启动 `nvim` 时自动安装（见下） |
| `config/starship/starship.toml` | `~/.config/starship.toml` | 统一 shell prompt：目录、git、node/python 版本、kubernetes context、命令耗时 |
| `config/tmux/tmux.conf` | `~/.tmux.conf` | 鼠标、256 色、vi 复制模式、直观分屏、vi 风格 pane 导航 |
| `config/bat/config` | `~/.config/bat/config` | bat 主题和显示风格 |
| `config/lazygit/config.yml` | `~/.config/lazygit/config.yml` | lazygit 界面（无外部 pager 依赖的基础版） |
| `config/lazygit/config.delta.yml` | `~/.config/lazygit/config.yml`（仅在检测到 delta 时使用） | 在基础版之上启用 delta pager |
| `config/git/gitconfig.shared` | `~/.config/git/catalog.gitconfig` | 通过 `include.path` 引入的共享 Git 配置：常用 alias、合理默认值（不含身份，无外部依赖） |
| `config/git/gitconfig.delta` | `~/.config/git/catalog-delta.gitconfig` | delta pager 设置，仅在检测到 `delta` 时才通过 `include.path` 引入 |
| `config/bash/aliases.sh` | `~/.config/personal-app-catalog/aliases.sh` | 常用 alias（`ll`、`gs`、`lg` 等）、当前 shell 代理开关，从 `.bashrc` guarded 块 source |

## Neovim 插件与依赖

`init.lua` 通过 `lazy.nvim` 安装：tokyonight、treesitter、telescope、nvim-cmp（+ LuaSnip/friendly-snippets 补全与片段）、mason + mason-lspconfig + lspconfig（自动安装并接线 `lua_ls`、`pyright`、`ts_ls`、`bashls`、`jsonls`、`yamlls`，补全 capability 来自 cmp）、conform.nvim（格式化，`<leader>f`）、trouble.nvim（诊断列表 `<leader>xx`）、oil.nvim（文件浏览 `-`）、gitsigns、lualine、which-key、Comment、autopairs。

formatter 本体（stylua、prettier、ruff、black、shfmt）由 `mason-tool-installer` 通过 mason 自动安装，独立于宿主工具链，所以 `<leader>f` 格式化入口的依赖是闭环的；conform 也配了 `lsp_fallback`，缺某个 formatter 时回退到 LSP 格式化。

常用键位：`gd`/`gr`/`K`/`<leader>rn`/`<leader>ca`（LSP）、`<leader>ff`/`<leader>fg`/`<leader>fb`（telescope）。

**剪贴板桥接**：`clipboard=unnamedplus` 在 WSL 里要与 Windows 剪贴板互通，需要 `win32yank.exe` 在 PATH 上。`init.lua` 检测到它时会自动配置 `vim.g.clipboard`；没有则保持默认。`win32yank` 是 Windows 侧辅助工具，不由本脚本自动安装（可从其 release 下载放入 PATH）。

## 代理

WSL 代理策略见 `wsl/docs/proxy.md`。本项目推荐 Windows mihomo 作为代理入口，WSL 使用 mirrored networking、autoProxy 和 `./wsl/bootstrap.sh --proxy` 写入的常开代理。

`config/bash/aliases.sh` 提供当前 shell 的代理开关：

```bash
proxy_on
proxy_status
proxy_off
```

`./wsl/bootstrap.sh --proxy` 会持久化 shell、apt、Git 和 Docker daemon 代理；这些函数用于当前 shell 的临时覆盖、关闭和诊断。SSH 代理等更细配置按 `wsl/docs/proxy.md` 手工处理。

## 依赖闭环与执行顺序

- **delta**：Git 的 pager 配置拆到独立的 `gitconfig.delta`，`--config` 只在检测到 `delta` 时才引入它；lazygit 也同理——检测到 delta 用 `config.delta.yml`，否则用无依赖的 `config.yml`。两者都不会因为缺 delta 而报错。
- **formatter**：Neovim 的 stylua/prettier/ruff/black/shfmt 由 mason 自动安装，不依赖 `cli.txt`。
- **推荐顺序**：`delta@latest` 在 `cli.txt` 里，建议先 `--cli` 再 `--config`，这样 delta 相关增强（Git pager、lazygit pager）一步到位；但即使顺序颠倒或只跑 `--config`，也只是少了 delta pager，不会坏掉基础体验。

## 边界

- 模板不含身份、凭据、密钥、token 或个人历史；`wsl/validate.sh` 会扫描 `wsl/config/` 拦截 secret 赋值和 email。
- Git 身份仍写在你自己的 `~/.gitconfig`；本层只通过 `include.path` 叠加共享配置。
- 代理函数只提供本机默认地址和临时环境变量开关；常开代理由 `./wsl/bootstrap.sh --proxy` 写入运行期配置。mihomo 订阅、节点、secret、日志和缓存不入库。
- neovim 插件锁文件（`lazy-lock.json`）、zoxide 历史、tmux session、shell 历史等运行期状态按设备生成，不入库。

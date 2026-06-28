# macOS 工具配置层

`mac/config/` 是 opt-in 的脱敏配置模板。它只保存跨设备通用的工具偏好，不保存身份、token、账号、代理节点、证书或历史。

## 应用方式

先预览：

```bash
./mac/configure.sh --all --plan
```

确认后应用：

```bash
./mac/configure.sh --all
```

也可以分组应用：

```bash
./mac/configure.sh --zsh --git --vscode --plan
./mac/configure.sh --macos --plan
```

行为：

- 幂等。目标内容一致时跳过。
- 覆盖前先备份为 `<file>.bak.<timestamp>`。
- `--plan` 只打印计划，不写入 `$HOME`，不运行外部安装命令。
- Git 的 delta 配置和 lazygit 的 delta pager 只在检测到 `delta` 时启用。

## 模板清单

| 模板 | 目标路径 | 作用 |
|---|---|---|
| `config/zsh/rc.zsh` | `~/.config/personal-app-catalog/mac.zsh`，再由 `~/.zshrc` guarded 块 source | Homebrew PATH、mise、starship、zoxide、direnv、fzf、常用 alias |
| `config/git/gitconfig.shared` | `~/.config/personal-app-catalog/gitconfig.shared` | Git 共享默认值和 alias，不含身份 |
| `config/git/gitconfig.delta` | `~/.config/personal-app-catalog/gitconfig.delta` | delta pager 设置，仅在 delta 已安装时 include |
| `config/vscode/extensions.txt` | 通过 `code --install-extension` 安装 | 推荐扩展，不含私有 feed |
| `config/vscode/settings.json` | `~/Library/Application Support/Code/User/settings.json` | 脱敏 VS Code 设置，使用 `jq` deep-merge |
| `config/starship/starship.toml` | `~/.config/starship.toml` | shell prompt |
| `config/tmux/tmux.conf` | `~/.tmux.conf` | tmux 鼠标、分屏、vi 复制模式 |
| `config/bat/config` | `~/.config/bat/config` | bat 显示风格 |
| `config/lazygit/config.yml` | `~/Library/Application Support/lazygit/config.yml` | lazygit 基础配置 |
| `config/lazygit/config.delta.yml` | 同上，仅 delta 可用时使用 | lazygit + delta pager |
| `config/macos/defaults.sh` | 通过 `defaults write` 应用 | Finder、Dock、键盘、截图、安全提示等非敏感系统默认值 |

## macOS defaults

`config/macos/defaults.sh` 做的是可逆、非账号、非隐私的系统偏好：

- Finder 显示扩展名、隐藏文件、路径栏、状态栏；
- 网络盘/USB 不写 `.DS_Store`；
- Dock 自动隐藏、不显示最近使用；
- Mission Control 不按最近使用重排 Space；
- 键盘重复速度；
- 截图目录放到 `~/Pictures/Screenshots`；
- 屏保后立即要求密码。

它不会配置 Apple ID、iCloud、FileVault、Touch ID、系统登录项、隐私权限、网络位置、代理或任何证书。

## 边界

- Git 身份、签名、credential helper 登录状态手工恢复。
- VS Code Settings Sync、GitHub/Microsoft 登录、Copilot/Codex/Claude 登录手工恢复。
- Raycast、PopClip、BetterDisplay、Typora、Proxyman 等授权和账号不入库。
- zsh 历史、fzf 历史、zoxide 数据、tmux session、lazygit state 不入库。


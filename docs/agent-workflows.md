# Agent 工作流

面向 Claude Code / Codex 等编码 agent 的操作手册：常见任务怎么做、改完怎么验证、边界在哪里。
仓库定位、架构和验证契约见根目录 `CLAUDE.md`，本文件只补充“任务模板 + 审核 + 边界”。

## 开始之前先读什么

1. `CLAUDE.md` —— 仓库是什么、manifest 是事实源、配置层规则、验证契约。
2. 与任务相关的清单/脚本：`windows/manifests/`、`wsl/packages/`、`mac/manifests/`、`windows/bootstrap.ps1`、`wsl/bootstrap.sh`、`mac/bootstrap.sh`。
3. 对应文档：`windows/docs/`、`wsl/docs/`、`mac/docs/`。

不要凭聊天里的偏好去改文档或清单结构；以仓库现有约定和 `validate` 为准。

## 改完一定要跑的验证

```powershell
.\windows\validate.ps1
```
```bash
bash wsl/validate.sh
shellcheck --severity=warning wsl/*.sh    # CI 也会跑
bash mac/validate.sh
shellcheck --severity=warning mac/*.sh mac/config/macos/defaults.sh
```

经验：本地工作区“看起来通过”不等于干净检出通过。涉及新增文件时，用干净树复核，避免被 `.gitignore` 静默吞掉：

```bash
tmp=$(mktemp -d); git archive --format=tar $(git write-tree) | tar -x -C "$tmp"
(cd "$tmp" && bash wsl/validate.sh && bash mac/validate.sh)
```

## 常见任务模板

### 新增一个 Windows 应用

1. 选定唯一来源（winget / msstore / scoop 其一，别跨包管理器重复）。
2. 加到对应 `windows/manifests/winget-<profile>.json`（或 `msstore-<profile>.txt`）。
3. 若涉及新 profile：在 `bootstrap.ps1` 的 `ValidateSet` 加项，建对应 `winget-<profile>.json`，并在 `windows/docs/catalog.md` 或 `README.md` 记录。
4. 遵守 WSL-first 边界：Docker、Node、K8s CLI、主力 CLI 工具链不进 Windows。
5. 跑 `windows\validate.ps1`。

### 调整 meta-profile / all 集合

- `default` = `core + agentic-dev`，保持精简，别往里塞设备相关/大件/维护类。
- 改 `all` 时，`bootstrap.ps1` 的 `all` 集合必须和 `windows/docs/catalog.md` 的 `all` 段**逐字一致**。

### 新增 WSL CLI 工具

1. 加到 `wsl/packages/cli.txt`（或 `k8s.txt`），每项必须带 mise `@` 选择器（`@latest`/`@lts`/精确版本）。
2. apt 基础包进 `apt-base.txt`；Docker 包进 `docker.txt`（五个必需包不能少）。
3. 跑 `bash wsl/validate.sh`。

### 新增 macOS 应用

1. 优先选 Homebrew formula/cask；Mac App Store、官方安装器、GitHub Release 只在来源稳定且有恢复价值时记录。
2. 加到对应 `mac/manifests/Brewfile-<profile>`，不要重复放到多个 profile。
3. 若涉及新 profile：同步 `mac/bootstrap.sh` 的 `VALID_PROFILES`、`mac/docs/catalog.md` profile 表和 `all` 边界。
4. 家庭枢纽服务只安装工具，不自动启用；真实 plist、配置、证书、订阅、设备 ID 和备份密钥写手工边界。
5. 跑 `bash mac/validate.sh` 和 shellcheck。

### 审核 / 扩展配置层

- 配置层模板在 `windows/config/`、`wsl/config/`、`mac/config/`，**不是** package profile：不要进 `ValidateSet`、`all`、`catalog.md` profile 表。
- 模板必须脱敏：无身份（`user.name`/`user.email`）、无 key/凭据/token、无个人历史。validator 会扫描 `*/config/` 拦截 secret 赋值和 email。
- 有外部依赖的配置要**按能力启用**（例：delta 的 Git/lazygit 配置只在检测到 delta 时引入），不要硬写死。
- 应用脚本保持 plan-first、覆盖前备份、幂等。`configure.ps1 -Plan` 必须无副作用（不跑外部命令），CI 在 Linux pwsh 上跑它。
- 新增 `config.yml`/`config.yaml` 命名的模板时注意 `.gitignore` 的 `**/config.yml` 规则会吞掉它，需要加 `!` 负向规则。

### 修 validation 失败

validator 报错通常指明缺失的对应物：profile 缺 manifest、manifest 缺文档、`all` 不一致、清单缺 `@` 选择器、必需文件缺失、config 模板含 secret/email。按提示补齐对应文件，再重跑相关 validator。

## AI 审核 checklist

- [ ] 单一来源，没有跨包管理器重复。
- [ ] profile / manifest / 文档三者一致（`all` 逐字一致）。
- [ ] WSL-first 边界没被破坏。
- [ ] 配置层模板脱敏，无身份/凭据/token/email。
- [ ] 有外部依赖的配置做了能力检测，而非硬依赖。
- [ ] plan-first、备份、幂等都还成立；`-Plan`/`--plan` 无副作用。
- [ ] Windows / WSL / macOS 相关 validator + shellcheck 通过（干净树复核）。
- [ ] 未提交机器状态、导出、报告、运行期 config、密钥订阅。

## Claude / Codex 权限与边界建议

- 允许：读仓库、改清单/脚本/文档、跑 validator/shellcheck/`-Plan`、本地 git。
- 谨慎/先确认：真实安装（`bootstrap`/`configure` 非 plan）、推送、建 PR、任何写入 `$HOME` 真实配置的操作。
- 禁止入库：身份、SSH/GPG 私钥、token、订阅/节点、license、导出/报告、运行期 config。
- 提交信息清晰描述“改了什么 + 为什么 + 怎么验证的”，并按需重跑 validator。

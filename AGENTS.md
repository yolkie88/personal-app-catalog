# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## What this repository is

A declarative catalog of the applications and developer tools worth restoring across machines, plus the scripts that install them. It is intentionally a *curated recovery catalog*, not a snapshot of any one machine. Three install surfaces:

- **Windows** (`windows/`) — PowerShell scripts that import package manifests via `winget`, the Microsoft Store, and optionally `scoop`.
- **WSL / Linux** (`wsl/`) — Bash scripts that install `apt` base packages, a `mise`-managed CLI toolchain, Kubernetes tools, and Docker Engine.
- **macOS** (`mac/`) — Bash scripts that install curated Homebrew/Brewfile profiles, optional `mise` developer/Kubernetes tools, and sanitized tool/macOS defaults. The current mac target is a long-running Mac mini home hub, but the default layer remains small.

There is no application code to build; the "product" is the manifests/package lists plus the scripts that consume them. The primary docs (`README.md`, files under `*/docs/`) are written in Chinese.

## Core architecture

Manifests are the single source of truth and the scripts only read them — never hardcode a package list in a script.

- **Windows profiles** map 1:1 to manifest files in `windows/manifests/`. A profile `foo` is driven by `winget-foo.json` (winget source) and optionally `msstore-foo.txt` (Microsoft Store IDs, one per line, `#` comments allowed). `windows/bootstrap.ps1`'s `-Profile` `[ValidateSet(...)]` enumerates every valid profile.
- **Meta-profiles** are resolved in `bootstrap.ps1`'s `Resolve-Profiles`: `default` → `core + agentic-dev`; `all` → a deliberately loose set (`core, agentic-dev, daily, media, gaming`), *not* everything.
- **WSL package lists** live in `wsl/packages/` and `wsl/bootstrap.sh` reads them directly: `apt-base.txt` (apt package names), `cli.txt` and `k8s.txt` (mise tool selectors, each requiring an `@` version like `@latest`/`@lts`/exact), `docker.txt` (apt packages for Docker Engine).
- **macOS profiles** map 1:1 to `mac/manifests/Brewfile-<profile>` and are installed by `mac/bootstrap.sh` via `brew bundle install --file`. `default` → `core + agentic-dev`; `all` is a loose Mac mini set (`core, agentic-dev, daily, desktop-enhance, home-hub, media`), not everything. `mac/packages/mise-cli.txt` and `mac/packages/mise-k8s.txt` hold mise selectors and every entry must include `@`.
- **WSL-first boundary** is an enforced invariant: Docker, Node.js, Kubernetes CLIs, and the main developer CLI toolchain belong in WSL, not Windows. `Docker.DockerDesktop`, `OpenJS.NodeJS.LTS`, and `OpenAI.Codex` are explicitly forbidden from the Windows manifests by validation.
- **The publish layer** handles winget *archive/portable* packages (for example Mihomo, WinSW, sing-box) that winget unzips into a hashed `%LOCALAPPDATA%\Microsoft\WinGet\Packages\<Id>_<source>\` folder with no PATH shim — hard to find and reference. `windows/manifests/tools-publish.json` maps each `wingetId` → `subdir`/`targetExe`, and `windows/publish-tools.ps1` (plan-first, idempotent, backs up before overwrite) copies the resolved exe into a stable tools root (default `C:\Tools`, override with `-ToolsRoot`). winget stays the version source — re-run publish after `winget upgrade`. Like the config layer this is **not** a winget profile (keep it out of `ValidateSet`/`all`/profile tables); validation requires every `wingetId` in the publish map to be installed by some `winget-*.json`. WinSW service definitions ship as sanitized anchors under `windows/proxy/*.example.xml` (binary only is published; registering the service is a manual admin step).

### The config (tool-optimization) layer

Separate from the *package* manifests, sanitized tool-config templates live in `windows/config/`, `wsl/config/`, and `mac/config/` (PowerShell profile + modules, Windows Terminal defaults, shared Git config, VS Code extensions + settings, Neovim/lazy.nvim, starship, tmux, bat, lazygit, bash/zsh aliases, macOS defaults). They are applied **opt-in** and **plan-first** by `windows/configure.ps1` (`-Pwsh`/`-Terminal`/`-Git`/`-VSCode`/`-All`, `-Plan`), `wsl/bootstrap.sh --config`, and `mac/configure.sh` (`--zsh`/`--git`/`--vscode`/`--starship`/`--tmux`/`--bat`/`--lazygit`/`--macos`/`--all`, `--plan`), all of which **back up any existing target before overwriting** and are idempotent (guarded shell/profile insertion via a `personal-app-catalog` marker; Git config layered via `include.path`). The VS Code layer manages only recommended extensions and sanitized settings defaults (deep-merged where supported) — never account/Settings-Sync keys or private feeds.

Key rules: the config layer is **not** a package profile — never add it to `bootstrap.ps1`'s `ValidateSet`, the mac `all` set, or profile tables. Templates must stay **template-only**: no identity (`user.name`/`user.email`), keys, credentials, tokens, or history — validators scan `*/config/` and fail on secret-like assignments or email strings. `windows/configure.ps1 -Plan` and `mac/configure.sh --plan` must remain side-effect-free enough for CI/dry-runs. delta-dependent Git settings live in a separate `gitconfig.delta` template that the appliers wire via `include.path` **only when `delta` is installed** (the base `gitconfig.shared` has no external dependency). See `windows/docs/config.md`, `wsl/docs/config.md`, and `mac/docs/config.md`.

### The validation contract (most important thing to preserve)

`windows/validate.ps1` enforces cross-file consistency, so a change in one place usually requires matching edits elsewhere or validation fails. When adding/renaming/removing a profile or package, keep these in sync:

- Every `bootstrap.ps1` profile (except `default`/`all`) must have a matching `winget-<profile>.json`, and vice versa.
- Every profile must be documented in `windows/docs/catalog.md` or `README.md`.
- The `all` set in `bootstrap.ps1` must exactly match the `all` section listed in `windows/docs/catalog.md`.
- No duplicate package across winget manifests; no duplicate Microsoft Store ID; Store IDs must be alphanumeric.
- `cli.txt` / `k8s.txt` entries must carry a mise `@` selector; `docker.txt` must contain the five required Docker packages (`docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, `docker-compose-plugin`).
- `.gitignore` must keep the secret/export patterns; required Windows/WSL files (now including `windows/configure.ps1`, the `windows/config/`+`wsl/config/` templates, and the two `config.md` docs) must exist.
- Config templates under `windows/config/` and `wsl/config/` are secret-scanned — no key/credential/token assignments or email identity strings.
- macOS `Brewfile-*` profiles must match `mac/bootstrap.sh`; `all` must exactly match `mac/docs/catalog.md`; no duplicate Homebrew formula/cask across profiles; mac config templates are secret-scanned.

`wsl/validate.sh` re-checks the WSL-side invariants (package lists, Docker packages, WSL-first boundary) and runs `bash -n` syntax checks.

`mac/validate.sh` re-checks macOS profile/Brewfile consistency, mise selectors, home-hub service list format, config template sanitization, `.gitignore` rules, and shell syntax.

## Commands

Validation (run all relevant validators before committing; CI runs them on every push/PR):

```powershell
.\windows\validate.ps1     # Windows-side manifest/profile/doc consistency
```
```bash
bash wsl/validate.sh       # WSL-side package lists, boundaries, shell syntax
```
```bash
bash mac/validate.sh       # macOS profile/Brewfile/config consistency
```

CI (`.github/workflows/validate.yml`) additionally runs `shellcheck --severity=warning` on the WSL and macOS shell scripts — keep them shellcheck-clean.

Windows install (always preview with `-Plan` first; `-Report` writes JSON+txt to `windows/reports/`):

```powershell
.\windows\bootstrap.ps1 -Plan -Report                  # default layer (core + agentic-dev)
.\windows\bootstrap.ps1 -Report                        # apply default layer
.\windows\bootstrap.ps1 -Profile daily,network -Plan   # explicit / combined profiles
.\windows\bootstrap.ps1 -WithScoop -Report             # also install scoop-cli.txt packages
```

WSL install (must run inside an installed Linux distro; default baseline `Ubuntu-26.04`):

```bash
./wsl/bootstrap.sh --base --cli --k8s --plan   # preview
./wsl/bootstrap.sh --base --cli --k8s          # apply
./wsl/bootstrap.sh --docker                    # Docker Engine in WSL (Ubuntu/Debian only)
./wsl/bootstrap.sh --config --plan             # preview tool-config templates (backs up existing files)
./wsl/bootstrap.sh --config                    # apply tool-config templates
```

macOS install (always preview with `--plan` first):

```bash
./mac/bootstrap.sh --plan
./mac/bootstrap.sh
./mac/bootstrap.sh --profile daily,desktop-enhance,home-hub --cli --k8s --plan
./mac/bootstrap.sh --profile daily,desktop-enhance,home-hub --cli --k8s
```

macOS tool/system config (opt-in, plan-first, backs up before overwriting):

```bash
./mac/configure.sh --all --plan
./mac/configure.sh --all
```

Tool-config layer (opt-in, plan-first, backs up before overwriting):

```powershell
.\windows\configure.ps1 -All -Plan            # preview PowerShell/Terminal/Git config
.\windows\configure.ps1 -All                  # apply (or -Pwsh / -Terminal / -Git individually)
```

Publish layer — copy winget archive/portable exes into a stable tools root (plan-first, idempotent, backs up before overwrite); re-run after `winget upgrade`:

```powershell
.\windows\publish-tools.ps1 -Plan             # preview copies into C:\Tools (per tools-publish.json)
.\windows\publish-tools.ps1                    # apply (or -ToolsRoot D:\Tools to relocate)
```

Distro management, updates, and snapshots:

```powershell
.\windows\wsl-distro.ps1 -Install -Distro Ubuntu-26.04 -SetDefault
.\windows\update.ps1 -All -IncludeScoop        # without -All only lists upgrades
.\windows\export.ps1                           # snapshot installed apps to windows/exports/
```

## Conventions

- **Plan-first.** Every installer supports a dry run (`-Plan` / `--plan`) that prints exactly what would run. Use it before any real install.
- **One primary source per app.** Don't list the same application under two package managers.
- **Keep the default layer small** — only `core` and `agentic-dev`. Sensitive, device-specific, large, or maintenance profiles must be installed explicitly.
- **Line endings:** `.gitattributes` forces LF on `*.sh`, `wsl/packages/*.txt`, `mac/packages/*.txt`, and config templates consumed by bash/macOS tooling — don't let a Windows checkout reintroduce CRLF.
- **Secrets and machine state never enter Git.** `.gitignore` blocks tokens, keys, subscriptions, exports/reports, and runtime config. Things that can't or shouldn't be auto-restored (licenses, hardware, accounts) are documented as "manual boundaries" in `windows/docs/manual-boundaries.md`, `wsl/docs/wsl-boundaries.md`, and `mac/docs/manual-boundaries.md` rather than scripted. Note the `**/config.yml` runtime-config rule also matches lazygit templates, so `wsl/config/lazygit/config.yml` and `mac/config/lazygit/config.yml` are explicitly re-allowed.
- After any manifest/profile/package-list change, re-run all validators — they will catch missing doc/profile/manifest counterparts.

## Where things are documented

`windows/docs/` covers the Windows catalog (`catalog.md`), per-app rationale (`apps.md`), source priority (`sources.md`), manual boundaries, operations, and the new-device `recovery-playbook.md`. `wsl/docs/` covers the WSL-first environment (`wsl.md`), tools (`tools.md`), and WSL boundaries. `mac/docs/` covers the macOS catalog, source policy, config layer, Mac mini home-hub boundaries, and manual recovery boundaries. `docs/agent-workflows.md` is the operations handbook for coding agents (task templates, review checklist, permission boundaries).

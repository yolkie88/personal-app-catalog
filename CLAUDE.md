# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

A declarative catalog of the applications and developer tools worth restoring across machines, plus the scripts that install them. It is intentionally a *curated recovery catalog*, not a snapshot of any one machine. Two install surfaces:

- **Windows** (`windows/`) — PowerShell scripts that import package manifests via `winget`, the Microsoft Store, and optionally `scoop`.
- **WSL / Linux** (`wsl/`) — Bash scripts that install `apt` base packages, a `mise`-managed CLI toolchain, Kubernetes tools, and Docker Engine.

There is no application code to build; the "product" is the manifests/package lists plus the scripts that consume them. The primary docs (`README.md`, files under `*/docs/`) are written in Chinese.

## Core architecture

Manifests are the single source of truth and the scripts only read them — never hardcode a package list in a script.

- **Windows profiles** map 1:1 to manifest files in `windows/manifests/`. A profile `foo` is driven by `winget-foo.json` (winget source) and optionally `msstore-foo.txt` (Microsoft Store IDs, one per line, `#` comments allowed). `windows/bootstrap.ps1`'s `-Profile` `[ValidateSet(...)]` enumerates every valid profile.
- **Meta-profiles** are resolved in `bootstrap.ps1`'s `Resolve-Profiles`: `default` → `core + agentic-dev`; `all` → a deliberately loose set (`core, agentic-dev, daily, media, gaming`), *not* everything.
- **WSL package lists** live in `wsl/packages/` and `wsl/bootstrap.sh` reads them directly: `apt-base.txt` (apt package names), `cli.txt` and `k8s.txt` (mise tool selectors, each requiring an `@` version like `@latest`/`@lts`/exact), `docker.txt` (apt packages for Docker Engine).
- **WSL-first boundary** is an enforced invariant: Docker, Node.js, Kubernetes CLIs, and the main developer CLI toolchain belong in WSL, not Windows. `Docker.DockerDesktop`, `OpenJS.NodeJS.LTS`, and `OpenAI.Codex` are explicitly forbidden from the Windows manifests by validation.

### The config (tool-optimization) layer

Separate from the *package* manifests, sanitized tool-config templates live in `windows/config/` and `wsl/config/` (PowerShell profile + modules, Windows Terminal defaults, shared Git config, Neovim/lazy.nvim, starship, tmux, bat, lazygit, bash aliases). They are applied **opt-in** and **plan-first** by `windows/configure.ps1` (`-Pwsh`/`-Terminal`/`-Git`/`-All`, `-Plan`) and `wsl/bootstrap.sh --config`, both of which **back up any existing target before overwriting** and are idempotent (guarded `$PROFILE`/`.bashrc` insertion via a `personal-app-catalog` marker; Git config layered via `include.path`).

Key rules: the config layer is **not** a winget profile — never add it to `bootstrap.ps1`'s `ValidateSet`, the `all` set, or the `catalog.md` profile tables. Templates must stay **template-only**: no identity (`user.name`/`user.email`), keys, credentials, tokens, or history — both validators scan `*/config/` and fail on secret-like assignments or email strings. `windows/configure.ps1 -Plan` must remain side-effect-free (no external commands) so CI can run it on Linux `pwsh`. See `windows/docs/config.md` and `wsl/docs/config.md`.

### The validation contract (most important thing to preserve)

`windows/validate.ps1` enforces cross-file consistency, so a change in one place usually requires matching edits elsewhere or validation fails. When adding/renaming/removing a profile or package, keep these in sync:

- Every `bootstrap.ps1` profile (except `default`/`all`) must have a matching `winget-<profile>.json`, and vice versa.
- Every profile must be documented in `windows/docs/catalog.md` or `README.md`.
- The `all` set in `bootstrap.ps1` must exactly match the `all` section listed in `windows/docs/catalog.md`.
- No duplicate package across winget manifests; no duplicate Microsoft Store ID; Store IDs must be alphanumeric.
- `cli.txt` / `k8s.txt` entries must carry a mise `@` selector; `docker.txt` must contain the five required Docker packages (`docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, `docker-compose-plugin`).
- `.gitignore` must keep the secret/export patterns; required Windows/WSL files (now including `windows/configure.ps1`, the `windows/config/`+`wsl/config/` templates, and the two `config.md` docs) must exist.
- Config templates under `windows/config/` and `wsl/config/` are secret-scanned — no key/credential/token assignments or email identity strings.

`wsl/validate.sh` re-checks the WSL-side invariants (package lists, Docker packages, WSL-first boundary) and runs `bash -n` syntax checks.

## Commands

Validation (run both before committing; CI runs them on every push/PR):

```powershell
.\windows\validate.ps1     # Windows-side manifest/profile/doc consistency
```
```bash
bash wsl/validate.sh       # WSL-side package lists, boundaries, shell syntax
```

CI (`.github/workflows/validate.yml`) additionally runs `shellcheck --severity=warning` on the WSL shell scripts — keep them shellcheck-clean.

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

Tool-config layer (opt-in, plan-first, backs up before overwriting):

```powershell
.\windows\configure.ps1 -All -Plan            # preview PowerShell/Terminal/Git config
.\windows\configure.ps1 -All                  # apply (or -Pwsh / -Terminal / -Git individually)
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
- **Line endings:** `.gitattributes` forces LF on `*.sh` and `wsl/packages/*.txt` because they're consumed by bash inside WSL — don't let a Windows checkout reintroduce CRLF.
- **Secrets and machine state never enter Git.** `.gitignore` blocks tokens, keys, subscriptions, exports/reports, and runtime config. Things that can't or shouldn't be auto-restored (licenses, hardware, accounts) are documented as "manual boundaries" in `windows/docs/manual-boundaries.md` and `wsl/docs/wsl-boundaries.md` rather than scripted.
- After any manifest/profile/package-list change, re-run both validators — they will catch missing doc/profile/manifest counterparts.

## Where things are documented

`windows/docs/` covers the Windows catalog (`catalog.md`), per-app rationale (`apps.md`), source priority (`sources.md`), manual boundaries, operations, and the new-device `recovery-playbook.md`. `wsl/docs/` covers the WSL-first environment (`wsl.md`), tools (`tools.md`), and WSL boundaries.

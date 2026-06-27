#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_DIR="${SCRIPT_DIR}/packages"
CONFIG_DIR="${SCRIPT_DIR}/config"

BOOTSTRAP_FAILURES=()

INSTALL_BASE=false
INSTALL_CLI=false
INSTALL_K8S=false
INSTALL_DOCKER=false
INSTALL_CONFIG=false
INSTALL_AGENTS=false
INSTALL_PROXY=false
PLAN=false
PROXY_HOST="127.0.0.1"
PROXY_PORT="7890"
NO_PROXY_LIST="localhost,127.0.0.1,::1,.local,.internal,.svc,.cluster.local,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"

usage() {
  cat <<'USAGE'
Usage: ./wsl/bootstrap.sh [options]

Options:
  --base      Install conservative apt base packages
  --cli       Install WSL-first developer CLI tools through mise where possible
  --k8s       Install Kubernetes / K3s CLI tools through mise where possible
  --docker    Install Docker Engine inside WSL
  --proxy     Configure persistent WSL proxy defaults for shell, apt, Git, and Docker
  --config    Apply tool config templates (nvim, starship, tmux, bat, lazygit, git, bash aliases)
  --agents    Install agentic coding CLIs from packages/agents.txt (Claude Code, Codex)
  --proxy-host HOST
              Proxy host for --proxy (default: 127.0.0.1; mirrored WSL can reach Windows localhost)
  --proxy-port PORT
              Proxy port for --proxy (default: 7890)
  --no-proxy-list LIST
              Comma-separated no_proxy list for --proxy
  --all       Install proxy + base + cli + k8s + docker + config + agents
  --plan      Print what would run without installing
  -h, --help  Show help

Recommended first run:
  ./wsl/bootstrap.sh --base --cli --k8s --plan
  ./wsl/bootstrap.sh --base --cli --k8s

Apply optimized tool configs (backs up existing files first):
  ./wsl/bootstrap.sh --config --plan
  ./wsl/bootstrap.sh --config

Docker-in-WSL run:
  ./wsl/bootstrap.sh --docker
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) INSTALL_BASE=true ;;
    --cli) INSTALL_CLI=true ;;
    --k8s) INSTALL_K8S=true ;;
    --docker) INSTALL_DOCKER=true ;;
    --proxy) INSTALL_PROXY=true ;;
    --config) INSTALL_CONFIG=true ;;
    --agents) INSTALL_AGENTS=true ;;
    --proxy-host)
      if [[ $# -lt 2 ]]; then
        echo "--proxy-host requires a value" >&2
        exit 1
      fi
      PROXY_HOST="$2"
      shift
      ;;
    --proxy-port)
      if [[ $# -lt 2 ]]; then
        echo "--proxy-port requires a value" >&2
        exit 1
      fi
      PROXY_PORT="$2"
      shift
      ;;
    --no-proxy-list)
      if [[ $# -lt 2 ]]; then
        echo "--no-proxy-list requires a value" >&2
        exit 1
      fi
      NO_PROXY_LIST="$2"
      shift
      ;;
    --all)
      INSTALL_PROXY=true
      INSTALL_BASE=true
      INSTALL_CLI=true
      INSTALL_K8S=true
      INSTALL_DOCKER=true
      INSTALL_CONFIG=true
      INSTALL_AGENTS=true
      ;;
    --plan) PLAN=true ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

if [[ "$INSTALL_BASE" == false && "$INSTALL_CLI" == false && "$INSTALL_K8S" == false && "$INSTALL_DOCKER" == false && "$INSTALL_CONFIG" == false && "$INSTALL_AGENTS" == false && "$INSTALL_PROXY" == false ]]; then
  usage
  exit 1
fi

run() {
  if [[ "$PLAN" == true ]]; then
    printf '[plan] %q ' "$@"
    printf '\n'
  else
    "$@"
  fi
}

print_file_items() {
  local file="$1"
  if [[ -f "$file" ]]; then
    grep -Ev '^[[:space:]]*(#|$)' "$file" || true
  fi
}

mise_bin() {
  if command -v mise >/dev/null 2>&1; then
    command -v mise
    return
  fi

  if [[ -x "$HOME/.local/bin/mise" ]]; then
    printf '%s\n' "$HOME/.local/bin/mise"
    return
  fi

  echo "mise is not available on PATH or at ${HOME}/.local/bin/mise." >&2
  return 1
}

load_os_release() {
  if [[ ! -r /etc/os-release ]]; then
    echo "Cannot read /etc/os-release; unsupported distribution." >&2
    exit 1
  fi

  # shellcheck disable=SC1091  # /etc/os-release is provided by the distro
  . /etc/os-release

  if [[ -z "${ID:-}" ]]; then
    echo "Cannot detect Linux distribution ID from /etc/os-release." >&2
    exit 1
  fi

  if [[ -z "${VERSION_CODENAME:-}" ]]; then
    echo "Cannot detect VERSION_CODENAME from /etc/os-release." >&2
    exit 1
  fi
}

install_apt_base() {
  local file="${PACKAGES_DIR}/apt-base.txt"
  local packages
  mapfile -t packages < <(print_file_items "$file")

  echo "==> apt base packages"
  printf '  %s\n' "${packages[@]}"

  run sudo apt-get update
  if [[ ${#packages[@]} -gt 0 ]]; then
    run sudo apt-get install -y "${packages[@]}"
  fi

  # Ubuntu/Debian package names may expose commands as fdfind/batcat.
  if [[ "$PLAN" == false ]]; then
    mkdir -p "$HOME/.local/bin"
    command -v fdfind >/dev/null 2>&1 && ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    command -v batcat >/dev/null 2>&1 && ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
  fi
}

ensure_mise_shell_activation() {
  local rc="${HOME}/.bashrc"
  if [[ "$PLAN" == true ]]; then
    echo "[plan] ensure 'mise activate bash' in ${rc}"
    return
  fi
  if [[ -f "$rc" ]] && grep -qF 'mise activate bash' "$rc"; then
    return
  fi
  cat >> "$rc" <<'RC'

# Put ~/.local/bin (mise binary, fd/bat shims) on PATH for non-login shells (e.g.
# `bash` from Windows reads ~/.bashrc but not ~/.profile), then activate mise.
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) [ -d "$HOME/.local/bin" ] && PATH="$HOME/.local/bin:$PATH" ;;
esac
command -v mise >/dev/null 2>&1 && eval "$(mise activate bash)"
RC
  echo "==> Enabled mise activation in ${rc}. Open a new shell or run: source ${rc}"
}

ensure_shell_hooks() {
  local rc="${HOME}/.bashrc"
  if [[ "$PLAN" == true ]]; then
    echo "[plan] ensure starship/zoxide/direnv/fzf hooks in ${rc}"
    return
  fi
  if [[ -f "$rc" ]] && grep -qF 'personal-app-catalog cli hooks' "$rc"; then
    return
  fi
  cat >> "$rc" <<'RC'

# personal-app-catalog cli hooks (each guarded so it no-ops until the tool exists)
command -v starship >/dev/null 2>&1 && eval "$(starship init bash)"
command -v zoxide   >/dev/null 2>&1 && eval "$(zoxide init bash)"
command -v direnv   >/dev/null 2>&1 && eval "$(direnv hook bash)"
if command -v fzf >/dev/null 2>&1; then
  if fzf --bash >/dev/null 2>&1; then
    eval "$(fzf --bash)"
  elif [[ -f /usr/share/doc/fzf/examples/key-bindings.bash ]]; then
    source /usr/share/doc/fzf/examples/key-bindings.bash
  fi
fi
RC
  echo "==> Added starship/zoxide/direnv/fzf hooks to ${rc}."
}

install_mise() {
  if ! command -v mise >/dev/null 2>&1 && [[ ! -x "$HOME/.local/bin/mise" ]]; then
    echo "==> installing mise"
    if [[ "$PLAN" == true ]]; then
      echo "[plan] curl https://mise.run | sh"
    else
      # mise is bootstrapped from its upstream installer (intentionally unpinned).
      curl https://mise.run | sh
      export PATH="$HOME/.local/bin:$PATH"
    fi
  fi

  ensure_mise_shell_activation
}

mise_use_global() {
  local tool="$1"
  if [[ "$PLAN" == true ]]; then
    echo "[plan] mise use -g -y ${tool}"
  else
    local bin
    bin="$(mise_bin)"
    "$bin" use -g -y "$tool"
  fi
}

install_cli_tools() {
  install_mise

  # Install prebuilt python (python-build-standalone) instead of compiling it via
  # pyenv. Compiling needs extra build deps and breaks when the cloned pyenv
  # scripts pick up CRLF line endings (e.g. with git core.autocrlf=true).
  export MISE_PYTHON_COMPILE=0

  echo "==> WSL CLI toolchain"
  local tools
  mapfile -t tools < <(print_file_items "${PACKAGES_DIR}/cli.txt")
  printf '  %s\n' "${tools[@]}"

  local failed=()
  for tool in "${tools[@]}"; do
    if ! mise_use_global "$tool"; then
      failed+=("$tool")
    fi
  done

  if [[ ${#failed[@]} -gt 0 ]]; then
    echo "WARNING: failed to install: ${failed[*]}" >&2
    BOOTSTRAP_FAILURES+=("${failed[@]}")
  fi
}

install_k8s_tools() {
  install_mise

  echo "==> WSL Kubernetes toolchain"
  local tools
  mapfile -t tools < <(print_file_items "${PACKAGES_DIR}/k8s.txt")
  printf '  %s\n' "${tools[@]}"

  local failed=()
  for tool in "${tools[@]}"; do
    if ! mise_use_global "$tool"; then
      failed+=("$tool")
    fi
  done

  if [[ ${#failed[@]} -gt 0 ]]; then
    echo "WARNING: failed to install: ${failed[*]}" >&2
    BOOTSTRAP_FAILURES+=("${failed[@]}")
  fi
}

install_docker_engine() {
  echo "==> Docker Engine inside WSL"
  local packages
  mapfile -t packages < <(print_file_items "${PACKAGES_DIR}/docker.txt")
  printf '  %s\n' "${packages[@]}"

  load_os_release

  case "$ID" in
    ubuntu|debian) ;;
    *)
      echo "Docker install currently supports Ubuntu or Debian WSL only. Detected: ${ID}." >&2
      exit 1
      ;;
  esac

  run sudo apt-get update
  run sudo apt-get install -y ca-certificates curl gnupg
  run sudo install -m 0755 -d /etc/apt/keyrings

  if [[ "$PLAN" == true ]]; then
    echo "[plan] install Docker apt repository for ${ID} ${VERSION_CODENAME} and docker engine packages"
  else
    curl -fsSL "https://download.docker.com/linux/${ID}/gpg" | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${ID} ${VERSION_CODENAME} stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  fi

  run sudo apt-get update
  if [[ ${#packages[@]} -gt 0 ]]; then
    run sudo apt-get install -y "${packages[@]}"
  fi
  run sudo usermod -aG docker "$(id -un)"

  echo "==> Docker installed. Restart this WSL session before using docker without sudo."
}

proxy_http_url() {
  printf 'http://%s:%s\n' "$PROXY_HOST" "$PROXY_PORT"
}

proxy_socks_url() {
  printf 'socks5h://%s:%s\n' "$PROXY_HOST" "$PROXY_PORT"
}

backup_runtime_file() {
  local path="$1"

  if [[ ! -f "$path" ]]; then
    return
  fi

  local backup
  backup="${path}.bak.$(date +%Y%m%d-%H%M%S)"
  if [[ "$PLAN" == true ]]; then
    echo "  [plan] backup ${path} -> ${backup}"
    return
  fi

  cp "$path" "$backup"
  echo "  backed up ${path} -> ${backup}"
}

ensure_proxy_env_sourcing() {
  local rc="${HOME}/.bashrc"
  local env_file="${HOME}/.config/personal-app-catalog/proxy.env"
  local marker="personal-app-catalog proxy env"

  if [[ "$PLAN" == true ]]; then
    echo "[plan] ensure persistent proxy env source block in ${rc}"
    return
  fi
  if [[ -f "$rc" ]] && grep -qF "$marker" "$rc"; then
    return
  fi
  cat >> "$rc" <<RC

# personal-app-catalog proxy env (persistent WSL proxy defaults)
[[ -f "${env_file}" ]] && source "${env_file}"
RC
  echo "==> Added persistent proxy env source block to ${rc}."
}

write_shell_proxy_env() {
  local env_dir="${HOME}/.config/personal-app-catalog"
  local env_file="${env_dir}/proxy.env"
  local http
  local socks
  http="$(proxy_http_url)"
  socks="$(proxy_socks_url)"

  echo "==> Persistent shell proxy environment"
  if [[ "$PLAN" == true ]]; then
    echo "  [plan] write ${env_file}"
    ensure_proxy_env_sourcing
    return
  fi

  mkdir -p "$env_dir"
  if [[ -f "$env_file" ]]; then
    backup_runtime_file "$env_file"
  fi
  cat > "$env_file" <<EOF
# personal-app-catalog persistent WSL proxy defaults.
# Generated by: ./wsl/bootstrap.sh --proxy
# Windows mihomo is expected to listen on ${PROXY_HOST}:${PROXY_PORT}; mirrored WSL
# networking lets Linux processes reach that Windows localhost address directly.
export http_proxy="${http}"
export https_proxy="${http}"
export HTTP_PROXY="${http}"
export HTTPS_PROXY="${http}"
export all_proxy="${socks}"
export ALL_PROXY="${socks}"
export no_proxy="${NO_PROXY_LIST}"
export NO_PROXY="${NO_PROXY_LIST}"
EOF
  echo "  wrote ${env_file}"
  ensure_proxy_env_sourcing

  # Make the proxy available to the remainder of this bootstrap run too.
  # shellcheck disable=SC1090
  source "$env_file"
}

configure_apt_proxy() {
  local http
  http="$(proxy_http_url)"
  local path="/etc/apt/apt.conf.d/99proxy"

  echo "==> apt proxy"
  if [[ "$PLAN" == true ]]; then
    echo "  [plan] sudo write ${path}"
    return
  fi

  if sudo test -f "$path"; then
    sudo cp "$path" "${path}.bak.$(date +%Y%m%d-%H%M%S)"
    echo "  backed up ${path}"
  fi
  {
    printf 'Acquire::http::Proxy "%s";\n' "$http"
    printf 'Acquire::https::Proxy "%s";\n' "$http"
  } | sudo tee "$path" >/dev/null
  echo "  wrote ${path}"
}

configure_git_proxy() {
  local http
  http="$(proxy_http_url)"
  local git_dir="${HOME}/.config/git"
  local proxy_config="${git_dir}/catalog-proxy.gitconfig"
  local gitconfig="${HOME}/.gitconfig"
  local marker="personal-app-catalog proxy include"

  echo "==> Git HTTPS proxy"
  if [[ "$PLAN" == true ]]; then
    echo "  [plan] write ${proxy_config}"
    echo "  [plan] ensure ${gitconfig} includes ${proxy_config}"
    return
  fi

  mkdir -p "$git_dir"
  if [[ -f "$proxy_config" ]]; then
    backup_runtime_file "$proxy_config"
  fi
  cat > "$proxy_config" <<EOF
# personal-app-catalog Git proxy defaults.
[http]
    proxy = ${http}
[https]
    proxy = ${http}
EOF
  echo "  wrote ${proxy_config}"

  if [[ -f "$gitconfig" ]] && grep -qF "$marker" "$gitconfig"; then
    return
  fi
  cat >> "$gitconfig" <<EOF

# ${marker}
[include]
    path = ${proxy_config}
EOF
  echo "  added Git proxy include to ${gitconfig}"
}

configure_docker_proxy() {
  local http
  http="$(proxy_http_url)"
  local dropin_dir="/etc/systemd/system/docker.service.d"
  local dropin="${dropin_dir}/proxy.conf"
  local docker_config="${HOME}/.docker/config.json"

  echo "==> Docker proxy"
  if [[ "$PLAN" == true ]]; then
    echo "  [plan] sudo write ${dropin}"
    echo "  [plan] write ${docker_config} only if it does not already exist"
    return
  fi

  sudo mkdir -p "$dropin_dir"
  if sudo test -f "$dropin"; then
    sudo cp "$dropin" "${dropin}.bak.$(date +%Y%m%d-%H%M%S)"
    echo "  backed up ${dropin}"
  fi
  {
    printf '[Service]\n'
    printf 'Environment="HTTP_PROXY=%s"\n' "$http"
    printf 'Environment="HTTPS_PROXY=%s"\n' "$http"
    printf 'Environment="NO_PROXY=%s"\n' "$NO_PROXY_LIST"
  } | sudo tee "$dropin" >/dev/null
  echo "  wrote ${dropin}"

  if command -v systemctl >/dev/null 2>&1 && systemctl list-units >/dev/null 2>&1; then
    sudo systemctl daemon-reload
    if systemctl list-unit-files docker.service --no-legend 2>/dev/null | grep -q '^docker.service'; then
      if systemctl is-active --quiet docker; then
        sudo systemctl restart docker
        echo "  restarted docker"
      else
        echo "  docker service is not active; proxy applies when it starts"
      fi
    fi
  fi

  mkdir -p "$(dirname "$docker_config")"
  if [[ -f "$docker_config" ]]; then
    echo "  [skip] ${docker_config} exists; not overwriting possible registry auth"
    return
  fi
  cat > "$docker_config" <<EOF
{
  "proxies": {
    "default": {
      "httpProxy": "${http}",
      "httpsProxy": "${http}",
      "noProxy": "${NO_PROXY_LIST}"
    }
  }
}
EOF
  echo "  wrote ${docker_config}"
}

configure_proxy() {
  echo "==> Persistent WSL proxy (${PROXY_HOST}:${PROXY_PORT})"
  write_shell_proxy_env
  configure_apt_proxy
  configure_git_proxy
  configure_docker_proxy
}

ensure_alias_sourcing() {
  local rc="${HOME}/.bashrc"
  local aliases_file="${HOME}/.config/personal-app-catalog/aliases.sh"
  if [[ "$PLAN" == true ]]; then
    echo "[plan] ensure aliases source block in ${rc}"
    return
  fi
  if [[ -f "$rc" ]] && grep -qF 'personal-app-catalog aliases' "$rc"; then
    return
  fi
  cat >> "$rc" <<RC

# personal-app-catalog aliases (guarded so it no-ops until the file exists)
[[ -f "${aliases_file}" ]] && source "${aliases_file}"
RC
  echo "==> Added aliases source block to ${rc}."
}

backup_then_copy() {
  local src="$1"
  local dst="$2"

  if [[ ! -f "$src" ]]; then
    echo "  [skip] template not found: ${src#"${SCRIPT_DIR}/"}" >&2
    return
  fi

  if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
    echo "  unchanged: ${dst}"
    return
  fi

  if [[ "$PLAN" == true ]]; then
    if [[ -f "$dst" ]]; then
      echo "  [plan] backup ${dst} then copy ${src#"${SCRIPT_DIR}/"}"
    else
      echo "  [plan] copy ${src#"${SCRIPT_DIR}/"} -> ${dst}"
    fi
    return
  fi

  mkdir -p "$(dirname "$dst")"
  if [[ -f "$dst" ]]; then
    local backup
    backup="${dst}.bak.$(date +%Y%m%d-%H%M%S)"
    mv "$dst" "$backup"
    echo "  backed up ${dst} -> ${backup}"
  fi
  cp "$src" "$dst"
  echo "  wrote ${dst}"
}

install_configs() {
  echo "==> Tool config templates"

  backup_then_copy "${CONFIG_DIR}/nvim/init.lua"        "${HOME}/.config/nvim/init.lua"
  backup_then_copy "${CONFIG_DIR}/starship/starship.toml" "${HOME}/.config/starship.toml"
  backup_then_copy "${CONFIG_DIR}/tmux/tmux.conf"       "${HOME}/.tmux.conf"
  backup_then_copy "${CONFIG_DIR}/bat/config"           "${HOME}/.config/bat/config"

  # lazygit: use the delta-enabled config only when delta is installed, otherwise the
  # dependency-free base config (its pager would point at a missing command otherwise).
  local lazygit_src="${CONFIG_DIR}/lazygit/config.yml"
  if command -v delta >/dev/null 2>&1; then
    lazygit_src="${CONFIG_DIR}/lazygit/config.delta.yml"
  fi
  backup_then_copy "$lazygit_src" "${HOME}/.config/lazygit/config.yml"

  backup_then_copy "${CONFIG_DIR}/bash/aliases.sh"      "${HOME}/.config/personal-app-catalog/aliases.sh"

  # Git: reference the shared config from the global config; identity stays manual.
  local git_shared="${HOME}/.config/git/catalog.gitconfig"
  backup_then_copy "${CONFIG_DIR}/git/gitconfig.shared" "$git_shared"
  ensure_git_include "$git_shared"

  # delta pager config is only worth wiring up when delta is actually installed,
  # otherwise Git would point its pager at a missing command.
  local git_delta="${HOME}/.config/git/catalog-delta.gitconfig"
  backup_then_copy "${CONFIG_DIR}/git/gitconfig.delta" "$git_delta"
  if [[ "$PLAN" == true ]]; then
    echo "  [plan] include ${git_delta} only if delta is installed"
  elif command -v delta >/dev/null 2>&1; then
    ensure_git_include "$git_delta"
  else
    echo "  [skip] delta not installed; not wiring delta pager (install via --cli)"
  fi

  ensure_alias_sourcing
}

ensure_git_include() {
  local path="$1"
  if ! command -v git >/dev/null 2>&1; then
    return
  fi
  if [[ "$PLAN" == true ]]; then
    echo "  [plan] git config --global include.path ${path}"
  elif git config --global --get-all include.path 2>/dev/null | grep -qxF "$path"; then
    echo "  include.path already references ${path}"
  else
    git config --global --add include.path "$path"
    echo "  added include.path -> ${path}"
  fi
}

install_apt_agent() {
  local name="$1"
  local package="$2"
  local channel="$3"

  load_os_release
  case "$ID" in
    ubuntu|debian) ;;
    *)
      echo "APT agent install currently supports Ubuntu or Debian WSL only. Detected: ${ID}." >&2
      return 1
      ;;
  esac

  # Claude Code publishes signed apt repositories. The source package and channel
  # stay in packages/agents.txt; the repository layout is vendor-defined.
  if [[ "$package" != "claude-code" ]]; then
    echo "Unsupported apt agent package '${package}' for ${name}." >&2
    return 1
  fi
  if [[ "$channel" != "stable" && "$channel" != "latest" ]]; then
    echo "Unsupported Claude Code apt channel '${channel}' for ${name}; use stable or latest." >&2
    return 1
  fi

  local key_url="https://downloads.claude.ai/keys/claude-code.asc"
  local keyring="/etc/apt/keyrings/claude-code.asc"
  local source_list="/etc/apt/sources.list.d/claude-code.list"
  local repo="https://downloads.claude.ai/claude-code/apt/${channel}"
  local expected_fingerprint="31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE"

  if [[ "$PLAN" == true ]]; then
    echo "  [plan] sudo install -d -m 0755 /etc/apt/keyrings"
    echo "  [plan] curl -fsSL ${key_url} | sudo tee ${keyring} >/dev/null"
    echo "  [plan] verify Claude Code apt key fingerprint ${expected_fingerprint}"
    echo "  [plan] write ${source_list}: deb [signed-by=${keyring}] ${repo} ${channel} main"
    echo "  [plan] sudo apt-get update"
    echo "  [plan] sudo apt-get install -y ${package}"
    return
  fi

  sudo install -d -m 0755 /etc/apt/keyrings
  curl -fsSL "$key_url" | sudo tee "$keyring" >/dev/null

  if command -v gpg >/dev/null 2>&1; then
    local fingerprint
    fingerprint="$(gpg --show-keys --with-colons "$keyring" | awk -F: '$1 == "fpr" { print $10; exit }')"
    if [[ "$fingerprint" != "$expected_fingerprint" ]]; then
      echo "Claude Code apt key fingerprint mismatch: got '${fingerprint}', expected '${expected_fingerprint}'." >&2
      return 1
    fi
  else
    echo "WARNING: gpg not found; cannot verify Claude Code apt key fingerprint." >&2
  fi

  printf 'deb [signed-by=%s] %s %s main\n' "$keyring" "$repo" "$channel" | sudo tee "$source_list" >/dev/null
  sudo apt-get update
  sudo apt-get install -y "$package"
}

install_installer_agent() {
  local name="$1"
  local url="$2"
  local script

  if [[ "$PLAN" == true ]]; then
    echo "  [plan] curl -fsSL ${url} -o <tmp> && bash <tmp> </dev/null   # ${name}"
    return
  fi

  # Download then run with stdin from /dev/null. Piping `curl | bash` makes an
  # installer's interactive prompt read leftover pipe data (e.g. Codex's "Start
  # now?") and some then try to launch in a non-tty; /dev/null makes them take
  # defaults non-interactively.
  script="$(mktemp)"
  if curl -fsSL "$url" -o "$script" && bash "$script" </dev/null; then
    rm -f "$script"
  else
    rm -f "$script"
    echo "WARNING: failed to install ${name} from ${url}" >&2
    return 1
  fi
}

install_agents() {
  local file="${PACKAGES_DIR}/agents.txt"
  echo "==> Agentic coding CLIs (official non-npm installers)"

  # Installer-based agents drop a self-contained binary into ~/.local/bin; make
  # sure that is on PATH for future shells even if --cli was not run.
  ensure_mise_shell_activation

  local line name method source extra
  while IFS= read -r line; do
    IFS='|' read -r name method source extra <<< "$line"
    if [[ -z "$name" || -z "$method" || -z "$source" ]]; then
      echo "  [skip] malformed entry: ${line}" >&2
      continue
    fi
    if command -v "$name" >/dev/null 2>&1; then
      echo "  present: ${name} (not reinstalled)"
      continue
    fi
    echo "  installing: ${name}"
    case "$method" in
      apt)
        if ! install_apt_agent "$name" "$source" "${extra:-stable}"; then
          BOOTSTRAP_FAILURES+=("${name}")
        fi
        ;;
      installer)
        if ! install_installer_agent "$name" "$source"; then
          BOOTSTRAP_FAILURES+=("${name}")
        fi
        ;;
      *)
        echo "WARNING: unsupported agent install method '${method}' for ${name}" >&2
        BOOTSTRAP_FAILURES+=("${name}")
        ;;
    esac
  done < <(print_file_items "$file")
}

if [[ "$INSTALL_PROXY" == true ]]; then
  configure_proxy
fi

if [[ "$INSTALL_BASE" == true ]]; then
  install_apt_base
fi

if [[ "$INSTALL_CLI" == true ]]; then
  install_cli_tools
fi

if [[ "$INSTALL_K8S" == true ]]; then
  install_k8s_tools
fi

if [[ "$INSTALL_DOCKER" == true ]]; then
  install_docker_engine
  if [[ "$INSTALL_PROXY" == true ]]; then
    configure_docker_proxy
  fi
fi

if [[ "$INSTALL_CONFIG" == true ]]; then
  install_configs
fi

if [[ "$INSTALL_AGENTS" == true ]]; then
  install_agents
fi

if [[ "$INSTALL_BASE" == true || "$INSTALL_CLI" == true ]]; then
  ensure_shell_hooks
fi

if [[ ${#BOOTSTRAP_FAILURES[@]} -gt 0 ]]; then
  echo "==> WSL bootstrap completed with failures:" >&2
  printf '  %s\n' "${BOOTSTRAP_FAILURES[@]}" >&2
  exit 1
fi

echo "==> WSL bootstrap completed."

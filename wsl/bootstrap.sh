#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_DIR="${SCRIPT_DIR}/packages"
CONFIG_DIR="${SCRIPT_DIR}/config"

INSTALL_BASE=false
INSTALL_CLI=false
INSTALL_K8S=false
INSTALL_DOCKER=false
INSTALL_CONFIG=false
PLAN=false

usage() {
  cat <<'USAGE'
Usage: ./wsl/bootstrap.sh [options]

Options:
  --base      Install conservative apt base packages
  --cli       Install WSL-first developer CLI tools through mise where possible
  --k8s       Install Kubernetes / K3s CLI tools through mise where possible
  --docker    Install Docker Engine inside WSL
  --config    Apply tool config templates (nvim, starship, tmux, bat, lazygit, git, bash aliases)
  --all       Install base + cli + k8s + docker + config
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
    --config) INSTALL_CONFIG=true ;;
    --all)
      INSTALL_BASE=true
      INSTALL_CLI=true
      INSTALL_K8S=true
      INSTALL_DOCKER=true
      INSTALL_CONFIG=true
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

if [[ "$INSTALL_BASE" == false && "$INSTALL_CLI" == false && "$INSTALL_K8S" == false && "$INSTALL_DOCKER" == false && "$INSTALL_CONFIG" == false ]]; then
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

# Put mise-managed toolchains (node, python, ...) on PATH.
eval "$(mise activate bash)"
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

  for tool in "${tools[@]}"; do
    mise_use_global "$tool"
  done
}

install_k8s_tools() {
  install_mise

  echo "==> WSL Kubernetes toolchain"
  local tools
  mapfile -t tools < <(print_file_items "${PACKAGES_DIR}/k8s.txt")
  printf '  %s\n' "${tools[@]}"

  for tool in "${tools[@]}"; do
    mise_use_global "$tool"
  done
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
fi

if [[ "$INSTALL_CONFIG" == true ]]; then
  install_configs
fi

if [[ "$INSTALL_BASE" == true || "$INSTALL_CLI" == true ]]; then
  ensure_shell_hooks
fi

echo "==> WSL bootstrap completed."

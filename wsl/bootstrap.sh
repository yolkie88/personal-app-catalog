#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_DIR="${SCRIPT_DIR}/packages"

INSTALL_BASE=false
INSTALL_CLI=false
INSTALL_K8S=false
INSTALL_DOCKER=false
PLAN=false

usage() {
  cat <<'USAGE'
Usage: ./wsl/bootstrap.sh [options]

Options:
  --base      Install conservative apt base packages
  --cli       Install WSL-first developer CLI tools through mise where possible
  --k8s       Install Kubernetes / K3s CLI tools through mise where possible
  --docker    Install Docker Engine inside WSL
  --all       Install base + cli + k8s + docker
  --plan      Print what would run without installing
  -h, --help  Show help

Recommended first run:
  ./wsl/bootstrap.sh --base --cli --k8s --plan
  ./wsl/bootstrap.sh --base --cli --k8s

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
    --all)
      INSTALL_BASE=true
      INSTALL_CLI=true
      INSTALL_K8S=true
      INSTALL_DOCKER=true
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

if [[ "$INSTALL_BASE" == false && "$INSTALL_CLI" == false && "$INSTALL_K8S" == false && "$INSTALL_DOCKER" == false ]]; then
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
    grep -Ev '^\s*(#|$)' "$file" || true
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

install_mise() {
  if ! command -v mise >/dev/null 2>&1; then
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
    "$HOME/.local/bin/mise" use -g -y "$tool"
  fi
}

install_cli_tools() {
  install_mise

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

  run sudo apt-get update
  run sudo apt-get install -y ca-certificates curl gnupg
  run sudo install -m 0755 -d /etc/apt/keyrings

  if [[ "$PLAN" == true ]]; then
    echo "[plan] install Docker apt repository and docker engine packages"
  else
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    # shellcheck disable=SC1091  # /etc/os-release is provided by the distro
    . /etc/os-release
    # shellcheck disable=SC2154  # VERSION_CODENAME comes from /etc/os-release
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  fi

  run sudo apt-get update
  if [[ ${#packages[@]} -gt 0 ]]; then
    run sudo apt-get install -y "${packages[@]}"
  fi
  run sudo usermod -aG docker "$(id -un)"

  echo "==> Docker installed. Restart this WSL session before using docker without sudo."
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

echo "==> WSL bootstrap completed."

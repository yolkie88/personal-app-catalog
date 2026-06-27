#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PACKAGES_DIR="${SCRIPT_DIR}/packages"

failures=()

add_failure() {
  failures+=("$1")
}

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    add_failure "Missing file: ${path#"${REPO_ROOT}/"}"
  fi
}

active_items() {
  local file="$1"
  grep -Ev '^[[:space:]]*(#|$)' "$file" || true
}

test_list_file() {
  local path="$1"
  local label="$2"
  local require_mise_spec="${3:-false}"
  local items=()
  mapfile -t items < <(active_items "$path")

  if [[ ${#items[@]} -eq 0 ]]; then
    add_failure "${label} has no active entries."
    return
  fi

  declare -A seen=()
  local item
  for item in "${items[@]}"; do
    if [[ -n "${seen[$item]:-}" ]]; then
      add_failure "Duplicate entry '${item}' in ${label}."
    fi
    seen[$item]=1

    if [[ "$require_mise_spec" == true && "$item" != *@* ]]; then
      add_failure "${label} entry '${item}' should include an explicit mise selector such as @latest, @lts, or an exact version."
    fi
  done
}

test_required_files() {
  local files=(
    "${SCRIPT_DIR}/bootstrap.sh"
    "${SCRIPT_DIR}/packages/apt-base.txt"
    "${SCRIPT_DIR}/packages/cli.txt"
    "${SCRIPT_DIR}/packages/k8s.txt"
    "${SCRIPT_DIR}/packages/docker.txt"
    "${SCRIPT_DIR}/packages/agents.txt"
    "${SCRIPT_DIR}/docs/wsl.md"
    "${SCRIPT_DIR}/docs/tools.md"
    "${SCRIPT_DIR}/docs/wsl-boundaries.md"
    "${SCRIPT_DIR}/docs/config.md"
    "${SCRIPT_DIR}/docs/proxy.md"
    "${SCRIPT_DIR}/docs/container-runtimes.md"
    "${SCRIPT_DIR}/config/nvim/init.lua"
    "${SCRIPT_DIR}/config/starship/starship.toml"
    "${SCRIPT_DIR}/config/tmux/tmux.conf"
    "${SCRIPT_DIR}/config/bat/config"
    "${SCRIPT_DIR}/config/lazygit/config.yml"
    "${SCRIPT_DIR}/config/lazygit/config.delta.yml"
    "${SCRIPT_DIR}/config/git/gitconfig.shared"
    "${SCRIPT_DIR}/config/git/gitconfig.delta"
    "${SCRIPT_DIR}/config/bash/aliases.sh"
  )

  local file
  for file in "${files[@]}"; do
    require_file "$file"
  done
}

test_package_lists() {
  test_list_file "${PACKAGES_DIR}/apt-base.txt" "wsl/packages/apt-base.txt"
  test_list_file "${PACKAGES_DIR}/cli.txt" "wsl/packages/cli.txt" true
  test_list_file "${PACKAGES_DIR}/k8s.txt" "wsl/packages/k8s.txt" true
  test_list_file "${PACKAGES_DIR}/docker.txt" "wsl/packages/docker.txt"
}

test_docker_list() {
  local file="${PACKAGES_DIR}/docker.txt"
  local required=(
    docker-ce
    docker-ce-cli
    containerd.io
    docker-buildx-plugin
    docker-compose-plugin
  )

  local item
  for item in "${required[@]}"; do
    if ! active_items "$file" | grep -qxF "$item"; then
      add_failure "wsl/packages/docker.txt missing required Docker package: ${item}"
    fi
  done
}

test_agents_list() {
  local file="${PACKAGES_DIR}/agents.txt"
  if [[ ! -f "$file" ]]; then
    add_failure "Missing wsl/packages/agents.txt"
    return
  fi

  local items=()
  mapfile -t items < <(active_items "$file")
  if [[ ${#items[@]} -eq 0 ]]; then
    add_failure "wsl/packages/agents.txt has no active entries."
    return
  fi

  declare -A seen=()
  local line name url
  for line in "${items[@]}"; do
    name="${line%%|*}"
    url="${line#*|}"
    if [[ "$name" == "$line" || -z "$name" || -z "$url" ]]; then
      add_failure "wsl/packages/agents.txt entry '${line}' must be '<binary>|<https-installer-url>'."
      continue
    fi
    if [[ -n "${seen[$name]:-}" ]]; then
      add_failure "Duplicate agent '${name}' in wsl/packages/agents.txt."
    fi
    seen[$name]=1
    if [[ "$url" != https://* ]]; then
      add_failure "wsl/packages/agents.txt entry '${name}' installer URL must use https://."
    fi
  done
}

test_config_templates() {
  local config_dir="${SCRIPT_DIR}/config"
  if [[ ! -d "$config_dir" ]]; then
    add_failure "Missing wsl/config templates directory."
    return
  fi

  # Config templates are tracked but must stay sanitized: no keys, credentials, or
  # real email identity. Identity and secrets are recovered manually per the boundary docs.
  local file
  while IFS= read -r -d '' file; do
    if grep -qE 'BEGIN [A-Z ]*PRIVATE KEY' "$file" ||
       grep -qiE '(password|secret|api[_-]?key|token)[[:space:]]*[:=]' "$file"; then
      add_failure "Config template ${file#"${REPO_ROOT}/"} contains a secret-like assignment."
    fi
    if grep -qE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' "$file"; then
      add_failure "Config template ${file#"${REPO_ROOT}/"} contains an email-like identity string."
    fi
  done < <(find "$config_dir" -type f -print0)
}

test_wsl_first_boundaries() {
  local agentic_manifest="${REPO_ROOT}/windows/manifests/winget-agentic-dev.json"
  if [[ ! -f "$agentic_manifest" ]]; then
    add_failure "Missing Windows agentic-dev manifest."
    return
  fi

  if grep -qE 'Docker\.DockerDesktop|OpenJS\.NodeJS\.LTS' "$agentic_manifest"; then
    add_failure "Docker Desktop and Node.js LTS should not be in Windows agentic-dev; they are WSL-first tools in this catalog."
  fi
}

test_shell_syntax() {
  bash -n "${SCRIPT_DIR}/bootstrap.sh"
  bash -n "${SCRIPT_DIR}/validate.sh"
}

test_required_files
test_package_lists
test_docker_list
test_agents_list
test_config_templates
test_wsl_first_boundaries
test_shell_syntax

if [[ ${#failures[@]} -gt 0 ]]; then
  echo "WSL validation failed:"
  printf -- '- %s\n' "${failures[@]}"
  exit 1
fi

echo "WSL validation passed."

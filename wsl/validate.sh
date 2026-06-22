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
    "${SCRIPT_DIR}/docs/wsl.md"
    "${SCRIPT_DIR}/docs/wsl-boundaries.md"
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
test_wsl_first_boundaries
test_shell_syntax

if [[ ${#failures[@]} -gt 0 ]]; then
  echo "WSL validation failed:"
  printf -- '- %s\n' "${failures[@]}"
  exit 1
fi

echo "WSL validation passed."

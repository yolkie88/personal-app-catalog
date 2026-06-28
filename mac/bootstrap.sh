#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="${SCRIPT_DIR}/manifests"
PACKAGES_DIR="${SCRIPT_DIR}/packages"

VALID_PROFILES=(
  "default"
  "core"
  "agentic-dev"
  "daily"
  "desktop-enhance"
  "communication"
  "dev-extra"
  "network-toolkit"
  "media"
  "creative"
  "maintenance"
  "home-hub"
  "containers"
  "local-ai"
  "mobile-dev"
  "gaming"
  "all"
)

PLAN=false
INSTALL_PROFILES=true
INSTALL_CLI=false
INSTALL_K8S=false
PROFILES=("default")
PROFILE_ARG_SEEN=false
RESOLVED_PROFILES=()

usage() {
  cat <<'USAGE'
Usage: ./mac/bootstrap.sh [options]

Options:
  --profile LIST
              Comma-separated Homebrew profiles to install (default: default)
  --no-profiles
              Skip Homebrew profiles; useful with --cli or --k8s only
  --cli       Install mise-managed developer runtimes from packages/mise-cli.txt
  --k8s       Install mise-managed Kubernetes tools from packages/mise-k8s.txt
  --all       Use the loose mac all profile and install --cli + --k8s
  --plan      Print what would run without installing
  -h, --help  Show help

Examples:
  ./mac/bootstrap.sh --plan
  ./mac/bootstrap.sh --profile home-hub --plan
  ./mac/bootstrap.sh --profile default,home-hub --cli --k8s
USAGE
}

contains_profile() {
  local needle="$1"
  local item
  for item in "${VALID_PROFILES[@]}"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

append_input_profile() {
  local profile="$1"
  if ! contains_profile "$profile"; then
    echo "Unknown mac profile: ${profile}" >&2
    usage >&2
    exit 1
  fi

  if [[ "$PROFILE_ARG_SEEN" == false ]]; then
    PROFILES=()
    PROFILE_ARG_SEEN=true
  fi
  PROFILES+=("$profile")
}

append_profile_list() {
  local list="$1"
  local old_ifs="$IFS"
  local item
  IFS=','
  # shellcheck disable=SC2206
  local parts=($list)
  IFS="$old_ifs"

  for item in "${parts[@]}"; do
    item="${item#"${item%%[![:space:]]*}"}"
    item="${item%"${item##*[![:space:]]}"}"
    [[ -n "$item" ]] && append_input_profile "$item"
  done
}

add_resolved_profile() {
  local profile="$1"
  local existing
  if [[ ${#RESOLVED_PROFILES[@]} -gt 0 ]]; then
    for existing in "${RESOLVED_PROFILES[@]}"; do
      [[ "$existing" == "$profile" ]] && return
    done
  fi
  RESOLVED_PROFILES+=("$profile")
}

resolve_profiles() {
  local profile
  RESOLVED_PROFILES=()
  for profile in "$@"; do
    case "$profile" in
      default)
        add_resolved_profile "core"
        add_resolved_profile "agentic-dev"
        ;;
      all)
        add_resolved_profile "core"
        add_resolved_profile "agentic-dev"
        add_resolved_profile "daily"
        add_resolved_profile "desktop-enhance"
        add_resolved_profile "home-hub"
        add_resolved_profile "media"
        ;;
      *)
        add_resolved_profile "$profile"
        ;;
    esac
  done
}

active_items() {
  local file="$1"
  if [[ -f "$file" ]]; then
    grep -Ev '^[[:space:]]*(#|$)' "$file" || true
  fi
}

require_darwin() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "mac/bootstrap.sh can only apply changes on macOS. Use --plan on other systems." >&2
    exit 1
  fi
}

require_brew() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is not installed. Install Homebrew first: https://brew.sh" >&2
    exit 1
  fi
}

require_mise() {
  if command -v mise >/dev/null 2>&1; then
    return
  fi

  require_brew
  echo "==> Installing mise"
  brew install mise
}

print_brewfile_items() {
  local file="$1"
  while IFS= read -r line; do
    printf '    %s\n' "$line"
  done < <(active_items "$file")
}

install_brew_profile() {
  local profile="$1"
  local file="${MANIFEST_DIR}/Brewfile-${profile}"

  if [[ ! -f "$file" ]]; then
    echo "Missing Brewfile for mac profile '${profile}': ${file}" >&2
    exit 1
  fi

  if [[ "$PLAN" == true ]]; then
    echo "==> Plan: Homebrew profile: ${profile}"
    print_brewfile_items "$file"
  else
    require_darwin
    require_brew
    echo "==> Installing Homebrew profile: ${profile}"
    brew bundle install --file "$file"
  fi
}

install_mas_profile() {
  local profile="$1"
  local file="${MANIFEST_DIR}/mas-${profile}.txt"
  local line package_id label

  [[ -f "$file" ]] || return 0

  if [[ "$PLAN" == true ]]; then
    echo "==> Plan: Mac App Store packages: ${profile}"
    while IFS= read -r line; do
      package_id="${line%%[[:space:]]*}"
      label="${line#"$package_id"}"
      printf '    %s%s\n' "$package_id" "$label"
    done < <(active_items "$file")
    return
  fi

  require_darwin
  if ! command -v mas >/dev/null 2>&1; then
    echo "mas is not installed. Install the core profile first, then rerun." >&2
    exit 1
  fi

  while IFS= read -r line; do
    package_id="${line%%[[:space:]]*}"
    [[ -n "$package_id" ]] || continue
    echo "==> Installing Mac App Store package: ${package_id}"
    mas install "$package_id"
  done < <(active_items "$file")
}

install_mise_file() {
  local label="$1"
  local file="$2"
  local tool

  if [[ ! -f "$file" ]]; then
    echo "Missing mise package list: ${file}" >&2
    exit 1
  fi

  if [[ "$PLAN" == true ]]; then
    echo "==> Plan: mise tools: ${label}"
    while IFS= read -r tool; do
      printf '    mise use -g -y %s\n' "$tool"
    done < <(active_items "$file")
    return
  fi

  require_darwin
  require_mise
  while IFS= read -r tool; do
    [[ -n "$tool" ]] || continue
    echo "==> mise use -g -y ${tool}"
    mise use -g -y "$tool"
  done < <(active_items "$file")
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      if [[ $# -lt 2 ]]; then
        echo "--profile requires a value" >&2
        exit 1
      fi
      append_profile_list "$2"
      shift
      ;;
    --no-profiles)
      INSTALL_PROFILES=false
      ;;
    --cli)
      INSTALL_CLI=true
      ;;
    --k8s)
      INSTALL_K8S=true
      ;;
    --all)
      INSTALL_PROFILES=true
      PROFILE_ARG_SEEN=true
      PROFILES=("all")
      INSTALL_CLI=true
      INSTALL_K8S=true
      ;;
    --plan)
      PLAN=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [[ "$INSTALL_PROFILES" == false && "$INSTALL_CLI" == false && "$INSTALL_K8S" == false ]]; then
  usage
  exit 1
fi

if [[ "$INSTALL_PROFILES" == true ]]; then
  resolve_profiles "${PROFILES[@]}"
  for profile in "${RESOLVED_PROFILES[@]}"; do
    install_brew_profile "$profile"
    install_mas_profile "$profile"
  done
fi

if [[ "$INSTALL_CLI" == true ]]; then
  install_mise_file "developer runtimes" "${PACKAGES_DIR}/mise-cli.txt"
fi

if [[ "$INSTALL_K8S" == true ]]; then
  install_mise_file "Kubernetes tools" "${PACKAGES_DIR}/mise-k8s.txt"
fi

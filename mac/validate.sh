#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MANIFEST_DIR="${SCRIPT_DIR}/manifests"
PACKAGES_DIR="${SCRIPT_DIR}/packages"
CONFIG_DIR="${SCRIPT_DIR}/config"
BOOTSTRAP_PATH="${SCRIPT_DIR}/bootstrap.sh"
CONFIGURE_PATH="${SCRIPT_DIR}/configure.sh"
CATALOG_PATH="${SCRIPT_DIR}/docs/catalog.md"
GITIGNORE_PATH="${REPO_ROOT}/.gitignore"

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
  local require_mise_selector="${3:-false}"
  local items
  local duplicates

  if [[ ! -f "$path" ]]; then
    add_failure "Missing list file: ${label}"
    return
  fi

  items="$(active_items "$path")"
  if [[ -z "$items" ]]; then
    add_failure "${label} has no active entries."
    return
  fi

  duplicates="$(printf '%s\n' "$items" | sort | uniq -d)"
  if [[ -n "$duplicates" ]]; then
    while IFS= read -r item; do
      add_failure "Duplicate entry '${item}' in ${label}."
    done <<< "$duplicates"
  fi

  if [[ "$require_mise_selector" == true ]]; then
    while IFS= read -r item; do
      if [[ "$item" != *@* ]]; then
        add_failure "${label} entry '${item}' should include a mise selector such as @latest, @lts, or an exact version."
      fi
    done <<< "$items"
  fi
}

get_valid_profiles() {
  awk '
    /^VALID_PROFILES=\(/ { in_profiles=1; next }
    in_profiles && /^\)/ { in_profiles=0; next }
    in_profiles {
      gsub(/"/, "")
      for (i = 1; i <= NF; i++) print $i
    }
  ' "$BOOTSTRAP_PATH"
}

get_manifest_profiles() {
  find "$MANIFEST_DIR" -maxdepth 1 -type f -name 'Brewfile-*' -print |
    sed 's|.*/Brewfile-||' |
    sort -u
}

profile_exists() {
  local profile="$1"
  get_valid_profiles | grep -qxF "$profile"
}

test_required_files() {
  local files=(
    "${SCRIPT_DIR}/bootstrap.sh"
    "${SCRIPT_DIR}/configure.sh"
    "${SCRIPT_DIR}/validate.sh"
    "${SCRIPT_DIR}/manifests/Brewfile-core"
    "${SCRIPT_DIR}/manifests/Brewfile-agentic-dev"
    "${SCRIPT_DIR}/manifests/Brewfile-daily"
    "${SCRIPT_DIR}/manifests/Brewfile-desktop-enhance"
    "${SCRIPT_DIR}/manifests/Brewfile-home-hub"
    "${SCRIPT_DIR}/manifests/Brewfile-network-toolkit"
    "${SCRIPT_DIR}/packages/mise-cli.txt"
    "${SCRIPT_DIR}/packages/mise-k8s.txt"
    "${SCRIPT_DIR}/packages/services-home-hub.txt"
    "${SCRIPT_DIR}/docs/catalog.md"
    "${SCRIPT_DIR}/docs/apps.md"
    "${SCRIPT_DIR}/docs/config.md"
    "${SCRIPT_DIR}/docs/home-hub.md"
    "${SCRIPT_DIR}/docs/manual-boundaries.md"
    "${SCRIPT_DIR}/docs/operations.md"
    "${SCRIPT_DIR}/docs/sources.md"
    "${SCRIPT_DIR}/config/zsh/rc.zsh"
    "${SCRIPT_DIR}/config/git/gitconfig.shared"
    "${SCRIPT_DIR}/config/git/gitconfig.delta"
    "${SCRIPT_DIR}/config/vscode/extensions.txt"
    "${SCRIPT_DIR}/config/vscode/settings.json"
    "${SCRIPT_DIR}/config/starship/starship.toml"
    "${SCRIPT_DIR}/config/tmux/tmux.conf"
    "${SCRIPT_DIR}/config/bat/config"
    "${SCRIPT_DIR}/config/lazygit/config.yml"
    "${SCRIPT_DIR}/config/lazygit/config.delta.yml"
    "${SCRIPT_DIR}/config/macos/defaults.sh"
  )

  local file
  for file in "${files[@]}"; do
    require_file "$file"
  done
}

test_profile_manifest_sync() {
  local profile

  while IFS= read -r profile; do
    [[ "$profile" == "default" || "$profile" == "all" ]] && continue
    if [[ ! -f "${MANIFEST_DIR}/Brewfile-${profile}" ]]; then
      add_failure "bootstrap.sh profile '${profile}' has no matching mac/manifests/Brewfile-${profile}."
    fi
  done < <(get_valid_profiles)

  while IFS= read -r profile; do
    if ! profile_exists "$profile"; then
      add_failure "Brewfile-${profile} has no matching bootstrap.sh profile."
    fi
  done < <(get_manifest_profiles)
}

test_brewfile_syntax_and_duplicates() {
  local tmp
  tmp="$(mktemp)"

  local file
  while IFS= read -r -d '' file; do
    while IFS= read -r line; do
      [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
      if [[ "$line" =~ ^[[:space:]]*(brew|cask)[[:space:]]+\"([^\"]+)\" ]]; then
        printf '%s|%s|%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "$(basename "$file")" >> "$tmp"
      elif [[ "$line" =~ ^[[:space:]]*tap[[:space:]]+\"([^\"]+)\" ]]; then
        :
      else
        add_failure "$(basename "$file") has unsupported Brewfile line: ${line}"
      fi
    done < "$file"
  done < <(find "$MANIFEST_DIR" -maxdepth 1 -type f -name 'Brewfile-*' -print0)

  if [[ -s "$tmp" ]]; then
    while IFS='|' read -r type name first second; do
      add_failure "Duplicate Homebrew ${type} '${name}' in ${first} and ${second}."
    done < <(sort "$tmp" | awk -F'|' '
      {
        key = $1 "|" $2
        if (key == last_key) {
          if (!reported[key]) {
            print $1 "|" $2 "|" first_file[key] "|" $3
            reported[key] = 1
          }
        } else {
          first_file[key] = $3
        }
        last_key = key
      }
    ')
  fi

  rm -f "$tmp"
}

test_mas_manifests() {
  local tmp
  tmp="$(mktemp)"
  local file profile item package_id

  while IFS= read -r -d '' file; do
    profile="$(basename "$file")"
    profile="${profile#mas-}"
    profile="${profile%.txt}"
    if ! profile_exists "$profile"; then
      add_failure "$(basename "$file") has no matching bootstrap.sh profile."
    fi
    while IFS= read -r item; do
      package_id="${item%%[[:space:]]*}"
      if [[ ! "$package_id" =~ ^[0-9]+$ ]]; then
        add_failure "Mac App Store package ID '${package_id}' in $(basename "$file") should be numeric."
      fi
      printf '%s|%s\n' "$package_id" "$(basename "$file")" >> "$tmp"
    done < <(active_items "$file")
  done < <(find "$MANIFEST_DIR" -maxdepth 1 -type f -name 'mas-*.txt' -print0)

  if [[ -s "$tmp" ]]; then
    while IFS='|' read -r package_id first second; do
      add_failure "Duplicate Mac App Store package '${package_id}' in ${first} and ${second}."
    done < <(sort "$tmp" | awk -F'|' '
      {
        if ($1 == last) print $1 "|" first_file "|" $2
        else first_file = $2
        last = $1
      }
    ')
  fi

  rm -f "$tmp"
}

get_all_from_bootstrap() {
  awk '
    /all\)/ { in_all=1; next }
    in_all && /;;/ { in_all=0; next }
    in_all && /add_resolved_profile/ {
      gsub(/"/, "")
      print $2
    }
  ' "$BOOTSTRAP_PATH" | sort -u
}

get_all_from_catalog() {
  awk '
    /^## `all`/ { in_all=1; next }
    in_all && /^## / { in_all=0 }
    in_all && /^`all` 不包含/ { in_all=0 }
    in_all && /^- `/ {
      gsub(/`/, "")
      print $2
    }
  ' "$CATALOG_PATH" | sort -u
}

test_all_set_sync() {
  local bootstrap_all
  local catalog_all
  bootstrap_all="$(get_all_from_bootstrap)"
  catalog_all="$(get_all_from_catalog)"
  if [[ "$bootstrap_all" != "$catalog_all" ]]; then
    add_failure "mac bootstrap all set does not match mac/docs/catalog.md."
  fi
}

test_package_lists() {
  test_list_file "${PACKAGES_DIR}/mise-cli.txt" "mac/packages/mise-cli.txt" true
  test_list_file "${PACKAGES_DIR}/mise-k8s.txt" "mac/packages/mise-k8s.txt" true

  local services="${PACKAGES_DIR}/services-home-hub.txt"
  local line name method scope extra
  test_list_file "$services" "mac/packages/services-home-hub.txt"
  while IFS= read -r line; do
    IFS='|' read -r name method scope extra <<< "$line"
    if [[ -z "$name" || -z "$method" || -z "$scope" || -z "$extra" ]]; then
      add_failure "mac/packages/services-home-hub.txt entry '${line}' must be '<name>|brew-service|user|<note>' or '<name>|brew-service|root|<note>'."
      continue
    fi
    if [[ "$method" != "brew-service" ]]; then
      add_failure "mac/packages/services-home-hub.txt entry '${name}' has unsupported method '${method}'."
    fi
    if [[ "$scope" != "user" && "$scope" != "root" ]]; then
      add_failure "mac/packages/services-home-hub.txt entry '${name}' scope must be user or root."
    fi
  done < <(active_items "$services")
}

test_config_templates() {
  if [[ ! -d "$CONFIG_DIR" ]]; then
    add_failure "Missing mac/config templates directory."
    return
  fi

  local file
  while IFS= read -r -d '' file; do
    if grep -qE 'BEGIN [A-Z ]*PRIVATE KEY' "$file" ||
       grep -qiE '(password|secret|api[_-]?key|token)[[:space:]]*[:=]' "$file"; then
      add_failure "Config template ${file#"${REPO_ROOT}/"} contains a secret-like assignment."
    fi
    if grep -qE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' "$file"; then
      add_failure "Config template ${file#"${REPO_ROOT}/"} contains an email-like identity string."
    fi
  done < <(find "$CONFIG_DIR" -type f -print0)
}

test_gitignore_rules() {
  if [[ ! -f "$GITIGNORE_PATH" ]]; then
    add_failure "Missing .gitignore."
    return
  fi

  for pattern in 'mac/exports/' 'mac/reports/' '!mac/config/lazygit/config.yml'; do
    if ! grep -qxF "$pattern" "$GITIGNORE_PATH"; then
      add_failure ".gitignore missing required mac rule: ${pattern}"
    fi
  done
}

test_shell_syntax() {
  bash -n "$BOOTSTRAP_PATH"
  bash -n "$CONFIGURE_PATH"
  bash -n "${CONFIG_DIR}/macos/defaults.sh"
  bash -n "${SCRIPT_DIR}/validate.sh"
}

test_required_files
test_profile_manifest_sync
test_brewfile_syntax_and_duplicates
test_mas_manifests
test_all_set_sync
test_package_lists
test_config_templates
test_gitignore_rules
test_shell_syntax

if [[ ${#failures[@]} -gt 0 ]]; then
  echo "mac validation failed:"
  printf -- '- %s\n' "${failures[@]}"
  exit 1
fi

echo "mac validation passed."

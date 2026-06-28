#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config"
PERSONAL_CONFIG_DIR="${HOME}/.config/personal-app-catalog"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

PLAN=false
CONFIG_ZSH=false
CONFIG_GIT=false
CONFIG_VSCODE=false
CONFIG_STARSHIP=false
CONFIG_TMUX=false
CONFIG_BAT=false
CONFIG_LAZYGIT=false
CONFIG_MACOS=false

usage() {
  cat <<'USAGE'
Usage: ./mac/configure.sh [options]

Options:
  --zsh       Install guarded zsh hooks for mise, starship, zoxide, direnv, and fzf
  --git       Layer sanitized shared Git config via include.path
  --vscode    Install recommended VS Code extensions and merge sanitized settings
  --starship  Install starship prompt config
  --tmux      Install tmux config
  --bat       Install bat config
  --lazygit   Install lazygit config, using the delta variant when delta is present
  --macos     Apply non-secret macOS defaults for Finder, Dock, keyboard, and screenshots
  --all       Apply every config group
  --plan      Print actions without changing files or running external tools
  -h, --help  Show help

Recommended first run:
  ./mac/configure.sh --all --plan
  ./mac/configure.sh --all
USAGE
}

require_darwin_apply() {
  if [[ "$PLAN" == false && "$(uname -s)" != "Darwin" ]]; then
    echo "mac/configure.sh can only apply changes on macOS. Use --plan on other systems." >&2
    exit 1
  fi
}

backup_existing() {
  local target="$1"
  if [[ -e "$target" || -L "$target" ]]; then
    local backup="${target}.bak.${TIMESTAMP}"
    cp -p "$target" "$backup"
    echo "    backed up ${target} -> ${backup}"
  fi
}

copy_with_backup() {
  local source="$1"
  local target="$2"

  if [[ "$PLAN" == true ]]; then
    echo "[plan] copy ${source} -> ${target} (backup first if target exists)"
    return
  fi

  mkdir -p "$(dirname "$target")"
  if [[ -f "$target" ]] && cmp -s "$source" "$target"; then
    echo "==> Unchanged: ${target}"
    return
  fi

  backup_existing "$target"
  cp "$source" "$target"
  echo "==> Wrote ${target}"
}

ensure_block() {
  local target="$1"
  local marker="$2"
  local block="$3"

  if [[ "$PLAN" == true ]]; then
    echo "[plan] ensure marker '${marker}' in ${target}"
    return
  fi

  mkdir -p "$(dirname "$target")"
  touch "$target"
  if grep -qF "$marker" "$target"; then
    echo "==> Marker already present in ${target}: ${marker}"
    return
  fi

  backup_existing "$target"
  {
    printf '\n'
    printf '%s\n' "$block"
  } >> "$target"
  echo "==> Added marker to ${target}: ${marker}"
}

apply_zsh() {
  local source="${CONFIG_DIR}/zsh/rc.zsh"
  local target="${PERSONAL_CONFIG_DIR}/mac.zsh"
  local zshrc="${HOME}/.zshrc"
  local marker="# personal-app-catalog mac zsh"
  local block

  copy_with_backup "$source" "$target"
  block=$(cat <<'BLOCK'
# personal-app-catalog mac zsh
if [ -f "$HOME/.config/personal-app-catalog/mac.zsh" ]; then
  . "$HOME/.config/personal-app-catalog/mac.zsh"
fi
# end personal-app-catalog mac zsh
BLOCK
)
  ensure_block "$zshrc" "$marker" "$block"
}

apply_git() {
  local shared_source="${CONFIG_DIR}/git/gitconfig.shared"
  local delta_source="${CONFIG_DIR}/git/gitconfig.delta"
  local shared_target="${PERSONAL_CONFIG_DIR}/gitconfig.shared"
  local delta_target="${PERSONAL_CONFIG_DIR}/gitconfig.delta"
  local gitconfig="${HOME}/.gitconfig"
  local base_marker="# personal-app-catalog git shared"
  local delta_marker="# personal-app-catalog git delta"
  local base_block
  local delta_block

  copy_with_backup "$shared_source" "$shared_target"
  copy_with_backup "$delta_source" "$delta_target"

  base_block=$(cat <<'BLOCK'
# personal-app-catalog git shared
[include]
	path = ~/.config/personal-app-catalog/gitconfig.shared
# end personal-app-catalog git shared
BLOCK
)
  ensure_block "$gitconfig" "$base_marker" "$base_block"

  delta_block=$(cat <<'BLOCK'
# personal-app-catalog git delta
[include]
	path = ~/.config/personal-app-catalog/gitconfig.delta
# end personal-app-catalog git delta
BLOCK
)

  if [[ "$PLAN" == true ]]; then
    echo "[plan] include delta git config only when the delta command is available"
  elif command -v delta >/dev/null 2>&1; then
    ensure_block "$gitconfig" "$delta_marker" "$delta_block"
  else
    echo "==> delta not found; skipped delta Git include. Install git-delta to enable it."
  fi
}

apply_vscode_settings() {
  local source="${CONFIG_DIR}/vscode/settings.json"
  local target="${HOME}/Library/Application Support/Code/User/settings.json"
  local tmp

  if [[ "$PLAN" == true ]]; then
    echo "[plan] deep-merge ${source} into ${target} (backup first)"
    return
  fi

  mkdir -p "$(dirname "$target")"
  backup_existing "$target"

  if command -v jq >/dev/null 2>&1; then
    tmp="$(mktemp)"
    if [[ -f "$target" && -s "$target" ]]; then
      jq -s '.[0] * (.[1] | del(._comment))' "$target" "$source" > "$tmp"
    else
      jq 'del(._comment)' "$source" > "$tmp"
    fi
    mv "$tmp" "$target"
  else
    cp "$source" "$target"
    echo "    jq is not installed; copied template instead of deep-merging."
  fi
  echo "==> Wrote VS Code settings: ${target}"
}

apply_vscode_extensions() {
  local file="${CONFIG_DIR}/vscode/extensions.txt"
  local extension
  local code_bin="code"

  if [[ "$PLAN" == true ]]; then
    echo "==> Plan: VS Code extensions"
    while IFS= read -r extension; do
      printf '    code --install-extension %s\n' "$extension"
    done < <(grep -Ev '^[[:space:]]*(#|$)' "$file" || true)
    return
  fi

  if ! command -v "$code_bin" >/dev/null 2>&1; then
    if [[ -x "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]]; then
      code_bin="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
    else
      echo "==> VS Code CLI 'code' not found; skipped extension install."
      return
    fi
  fi

  while IFS= read -r extension; do
    [[ -n "$extension" ]] || continue
    "$code_bin" --install-extension "$extension"
  done < <(grep -Ev '^[[:space:]]*(#|$)' "$file" || true)
}

apply_vscode() {
  apply_vscode_settings
  apply_vscode_extensions
}

apply_starship() {
  copy_with_backup "${CONFIG_DIR}/starship/starship.toml" "${HOME}/.config/starship.toml"
}

apply_tmux() {
  copy_with_backup "${CONFIG_DIR}/tmux/tmux.conf" "${HOME}/.tmux.conf"
}

apply_bat() {
  copy_with_backup "${CONFIG_DIR}/bat/config" "${HOME}/.config/bat/config"
  if [[ "$PLAN" == true ]]; then
    echo "[plan] rebuild bat cache when bat is available"
  elif command -v bat >/dev/null 2>&1; then
    bat cache --build >/dev/null 2>&1 || true
  fi
}

apply_lazygit() {
  local source="${CONFIG_DIR}/lazygit/config.yml"
  local target="${HOME}/Library/Application Support/lazygit/config.yml"
  if [[ "$PLAN" == false ]] && command -v delta >/dev/null 2>&1; then
    source="${CONFIG_DIR}/lazygit/config.delta.yml"
  fi
  if [[ "$PLAN" == true ]]; then
    echo "[plan] copy base lazygit config, or config.delta.yml when delta is available"
  fi
  copy_with_backup "$source" "$target"
}

apply_macos() {
  if [[ "$PLAN" == true ]]; then
    bash "${CONFIG_DIR}/macos/defaults.sh" --plan
  else
    bash "${CONFIG_DIR}/macos/defaults.sh"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --zsh) CONFIG_ZSH=true ;;
    --git) CONFIG_GIT=true ;;
    --vscode) CONFIG_VSCODE=true ;;
    --starship) CONFIG_STARSHIP=true ;;
    --tmux) CONFIG_TMUX=true ;;
    --bat) CONFIG_BAT=true ;;
    --lazygit) CONFIG_LAZYGIT=true ;;
    --macos) CONFIG_MACOS=true ;;
    --all)
      CONFIG_ZSH=true
      CONFIG_GIT=true
      CONFIG_VSCODE=true
      CONFIG_STARSHIP=true
      CONFIG_TMUX=true
      CONFIG_BAT=true
      CONFIG_LAZYGIT=true
      CONFIG_MACOS=true
      ;;
    --plan) PLAN=true ;;
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

if [[ "$CONFIG_ZSH" == false && "$CONFIG_GIT" == false && "$CONFIG_VSCODE" == false && "$CONFIG_STARSHIP" == false && "$CONFIG_TMUX" == false && "$CONFIG_BAT" == false && "$CONFIG_LAZYGIT" == false && "$CONFIG_MACOS" == false ]]; then
  usage
  exit 1
fi

require_darwin_apply

[[ "$CONFIG_ZSH" == true ]] && apply_zsh
[[ "$CONFIG_GIT" == true ]] && apply_git
[[ "$CONFIG_VSCODE" == true ]] && apply_vscode
[[ "$CONFIG_STARSHIP" == true ]] && apply_starship
[[ "$CONFIG_TMUX" == true ]] && apply_tmux
[[ "$CONFIG_BAT" == true ]] && apply_bat
[[ "$CONFIG_LAZYGIT" == true ]] && apply_lazygit
[[ "$CONFIG_MACOS" == true ]] && apply_macos

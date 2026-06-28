#!/usr/bin/env bash
set -euo pipefail

PLAN=false
if [[ "${1:-}" == "--plan" ]]; then
  PLAN=true
fi

run() {
  if [[ "$PLAN" == true ]]; then
    printf '[plan]'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

screenshots_dir="${HOME}/Pictures/Screenshots"

run mkdir -p "$screenshots_dir"

# Finder: expose useful file metadata and reduce hidden state.
run defaults write NSGlobalDomain AppleShowAllExtensions -bool true
run defaults write com.apple.finder AppleShowAllFiles -bool true
run defaults write com.apple.finder ShowPathbar -bool true
run defaults write com.apple.finder ShowStatusBar -bool true
run defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
run defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
run defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
run defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Dock and Mission Control: quieter defaults for a utility Mac.
run defaults write com.apple.dock autohide -bool true
run defaults write com.apple.dock show-recents -bool false
run defaults write com.apple.dock mru-spaces -bool false
run defaults write com.apple.dock minimize-to-application -bool true

# Keyboard and screenshots.
run defaults write NSGlobalDomain KeyRepeat -int 2
run defaults write NSGlobalDomain InitialKeyRepeat -int 15
run defaults write com.apple.screencapture location -string "$screenshots_dir"
run defaults write com.apple.screencapture type -string "png"
run defaults write com.apple.screencapture disable-shadow -bool true

# Security prompt for screensaver unlock.
run defaults write com.apple.screensaver askForPassword -int 1
run defaults write com.apple.screensaver askForPasswordDelay -int 0

if [[ "$PLAN" == true ]]; then
  echo "[plan] killall Finder Dock SystemUIServer"
else
  killall Finder >/dev/null 2>&1 || true
  killall Dock >/dev/null 2>&1 || true
  killall SystemUIServer >/dev/null 2>&1 || true
fi

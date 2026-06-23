# Managed by personal-app-catalog. Sanitized template only — no secrets, no identity.
# bootstrap.sh copies this to ~/.config/personal-app-catalog/aliases.sh and sources it
# from ~/.bashrc through a guarded block. Personal/private aliases belong elsewhere.

# Listing: prefer eza if present, otherwise fall back to coreutils ls.
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --group-directories-first'
  alias ll='eza -lah --group-directories-first --git'
  alias lt='eza --tree --level=2 --group-directories-first'
else
  alias ll='ls -lah'
  alias la='ls -A'
fi

# cat -> bat when available (bootstrap links batcat to bat on Ubuntu/Debian).
if command -v bat >/dev/null 2>&1; then
  alias cat='bat --paging=never'
fi

# Git shortcuts.
alias g='git'
alias gs='git status -sb'
alias gd='git diff'
alias gl='git log --oneline --graph --decorate -20'
alias lg='lazygit'

# Session-only proxy helpers. Assumes Windows mihomo listens on 127.0.0.1:7890.
# Works best with WSL mirrored networking; only affects the current shell and children.
proxy_on() {
  local proxy_host="${1:-127.0.0.1}"
  local proxy_port="${2:-7890}"
  local http="http://${proxy_host}:${proxy_port}"
  local socks="socks5h://${proxy_host}:${proxy_port}"
  local bypass="localhost,127.0.0.1,::1,.local,.internal,.svc,.cluster.local,10.0.0.0/8"

  export http_proxy="$http"
  export https_proxy="$http"
  export HTTP_PROXY="$http"
  export HTTPS_PROXY="$http"
  export all_proxy="$socks"
  export ALL_PROXY="$socks"
  export no_proxy="$bypass"
  export NO_PROXY="$bypass"

  echo "proxy on: ${http}"
}

proxy_off() {
  unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
  unset all_proxy ALL_PROXY no_proxy NO_PROXY
  echo "proxy off"
}

proxy_status() {
  env | grep -Ei '^(http|https|all|no)_proxy=' || true
}

# Quick connectivity + egress check. curl honours the proxy env automatically,
# whether it was set by proxy_on or injected by WSL autoProxy; with no proxy env
# it tests a direct connection. Tells apart "proxy down" from "no proxy active".
proxy_test() {
  local probe="${1:-https://www.gstatic.com/generate_204}"
  local ip_url="${2:-https://api.ipify.org}"

  if [ -n "${https_proxy:-}" ]; then
    echo "shell proxy: ${https_proxy}"
  else
    echo "shell proxy: none (direct)"
  fi

  local code
  code="$(curl -fsS -o /dev/null -w '%{http_code}' --max-time 8 "$probe" 2>/dev/null || true)"
  if [ -n "$code" ] && [ "$code" != "000" ]; then
    echo "connectivity: ok (${code})"
  else
    echo "connectivity: FAILED -> ${probe}"
  fi

  local ip
  ip="$(curl -fsS --max-time 8 "$ip_url" 2>/dev/null || true)"
  echo "egress ip: ${ip:-unavailable}"
}

# Safer defaults.
alias mkdir='mkdir -p'

# zoxide interactive jump (zoxide hook is added separately by bootstrap.sh).
command -v zoxide >/dev/null 2>&1 && alias zi='__zoxide_zi'

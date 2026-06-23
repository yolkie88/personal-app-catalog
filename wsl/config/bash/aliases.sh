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

# Safer defaults.
alias mkdir='mkdir -p'

# zoxide interactive jump (zoxide hook is added separately by bootstrap.sh).
command -v zoxide >/dev/null 2>&1 && alias zi='__zoxide_zi'

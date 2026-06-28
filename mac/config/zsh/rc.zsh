# Managed by personal-app-catalog. Sanitized template only.

case ":$PATH:" in
  *":/opt/homebrew/bin:"*) ;;
  *) [ -d /opt/homebrew/bin ] && PATH="/opt/homebrew/bin:$PATH" ;;
esac

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) [ -d "$HOME/.local/bin" ] && PATH="$HOME/.local/bin:$PATH" ;;
esac

command -v mise >/dev/null 2>&1 && eval "$(mise activate zsh)"
command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"

if command -v fzf >/dev/null 2>&1; then
  fzf_share="$(brew --prefix fzf 2>/dev/null)/shell"
  [ -r "$fzf_share/key-bindings.zsh" ] && . "$fzf_share/key-bindings.zsh"
  [ -r "$fzf_share/completion.zsh" ] && . "$fzf_share/completion.zsh"
  unset fzf_share
fi

alias ll='eza -lah --git --group-directories-first'
alias la='eza -la --git --group-directories-first'
alias gs='git status -sb'
alias lg='lazygit'


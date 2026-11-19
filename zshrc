# Portable zsh config: works on a fresh Linux/macOS host with or without
# oh-my-zsh. Optional switches: ZSH_NO_OMZ=1, ZSH_NO_STARSHIP=1.

[[ -o interactive ]] || return

# ---- history --------------------------------------------------------------
HISTFILE="${ZDOTDIR:-$HOME}/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt append_history share_history hist_ignore_dups hist_ignore_space
setopt hist_reduce_blanks auto_cd auto_pushd pushd_ignore_dups
setopt extended_glob interactive_comments no_beep

# ---- PATH -----------------------------------------------------------------
# Only add directories that exist; never hardcode a username.
typeset -U path
for _d in "$HOME/bin" "$HOME/.local/bin" "$HOME/.cargo/bin" "$HOME/go/bin"; do
  [[ -d $_d ]] && path=("$_d" $path)
done
unset _d

# ---- editor / pager -------------------------------------------------------
if [[ -z ${EDITOR:-} ]]; then
  for _e in vim vi nano; do
    if command -v $_e >/dev/null 2>&1; then export EDITOR=$_e; break; fi
  done
  unset _e
fi
[[ -n ${EDITOR:-} ]] && export VISUAL="${VISUAL:-$EDITOR}"
export PAGER="${PAGER:-less}"
export LESS="${LESS:--R}"

# ---- aliases --------------------------------------------------------------
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'

# ---- shell framework ------------------------------------------------------
if [[ -z ${ZSH_NO_OMZ:-} && -d $HOME/.oh-my-zsh ]]; then
  export ZSH="$HOME/.oh-my-zsh"
  # The visible prompt comes from starship below; this theme is only a fallback.
  ZSH_THEME="robbyrussell"
  plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
  zstyle ':omz:update' mode disabled   # no update prompts on shared servers
  source "$ZSH/oh-my-zsh.sh"
else
  autoload -Uz compinit && compinit
  zstyle ':completion:*' menu select
  PROMPT='%F{green}%n@%m%f:%F{blue}%~%f%# '
  alias gs='git status -sb'
  alias gd='git diff'
  alias glog='git log --oneline --graph --decorate -20'
fi

if [[ -z ${ZSH_NO_STARSHIP:-} ]] && command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

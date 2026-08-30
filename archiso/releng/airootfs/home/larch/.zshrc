export ZSH="$HOME/.oh-my-zsh"

DISABLE_AUTO_UPDATE=true

autoload -Uz compinit
compinit

ZSH_THEME="robbyrussell"
plugins=(dirhistory git zsh-autosuggestions zsh-syntax-highlighting fzf-tab)

source $ZSH/oh-my-zsh.sh

alias ls="eza --icons=auto"

# fzf for search history, file search etc.
source <(fzf --zsh)

eval "$(zoxide init zsh)"

# Lines configured by zsh-newuser-install
setopt appendhistory autocd extendedglob nomatch notify
unsetopt beep
bindkey -e
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/home/gmoshkin/.zshrc'

autoload -Uz compinit
compinit

autoload -Uz promptinit
promptinit

prompt mine

autoload -U select-word-style
select-word-style bash

source "$DOTFILES/aliases.sh"

eval `dircolors ~/.dir_colors/dircolors`
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}

source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# End of lines added by compinstall

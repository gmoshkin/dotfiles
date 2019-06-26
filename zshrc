# Lines configured by zsh-newuser-install
setopt appendhistory autocd extendedglob nomatch notify histignorealldups
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
source "$DOTFILES/commands.sh"

eval `dircolors ~/.dir_colors/dircolors`
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}

alias SZ="source ~/.zshrc && source ~/.zshenv"

bindkey "^U" backward-kill-line
bindkey "^\\" redo

# disable c-s binding (stop/start output control)
stty -ixon

source "$DOTFILES/utils.sh"
appendToPath "$DOTFILES/scripts"
appendToPath "$HOME/.cargo/bin"
appendToPath "$HOME/.perl6/bin"

local hlfile=/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
if [ -f "$hlfile" ]; then
    source "$hlfile"
fi

alias SB='source ~/.zshrc'

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
bindkey '^T' transpose-chars

# End of lines added by compinstall

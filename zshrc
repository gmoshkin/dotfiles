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
appendToPath "$HOME/.local/share/perl6/site/bin"
appendToPath "$DOTFILES/rakudobrew/bin"

source "$DOTFILES/rakudobrew_init.zsh"
rakudobrew switch &>/dev/null

source "$DOTFILES/aliases.sh"

local hlfiles=(
    /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
    /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
    /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
)
for hlfile in  ${hlfiles[@]}; do
    [ -f "$hlfile" ] && source "$hlfile"
done

export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=10"

alias SB='source ~/.zshrc'

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
bindkey '^T' transpose-chars
bindkey '^O' fzf-file-widget

source /usr/share/z/z.sh

export WORKON_HOME="${HOME}/.virtualenvs"
source /usr/bin/virtualenvwrapper.sh
[ -d "${WORKON_HOME}" ] || mkdir "${WORKON_HOME}"

eval "$(pip completion --zsh)"

# End of lines added by compinstall

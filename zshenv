HISTFILE=~/.histfile
HISTSIZE=99999999999
SAVEHIST=99999999999
DOTFILES=~/dotfiles
fpath=( "$DOTFILES/zcompletion" "$DOTFILES/zprompts" $fpath )

source "$DOTFILES/env.sh"

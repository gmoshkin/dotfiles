HISTFILE=~/.histfile
HISTSIZE=99999999999
SAVEHIST=99999999999
DOTFILES=~/dotfiles
EDITOR="/usr/bin/env nvim"
fpath=( "$DOTFILES/zcompletion" "$DOTFILES/zprompts" "$DOTFILES/asdf/completions" $fpath )

source "$DOTFILES/env.sh"
. "$HOME/.cargo/env"

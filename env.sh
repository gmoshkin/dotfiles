export EDITOR="$(which vim)"
export GDBHISTFILE="$HOME/.gdb_history"

export VIMFILES="$HOME/.vim"
export VIMSERV="/tmp/vim-serv-tmp"

export BASHRC="$HOME/.bashrc"

export GOPATH="$HOME/gocode"

export PERL6LIB="$HOME/dotfiles/scripts"

export LESS=RMWSJ
export SYSTEMD_LESS=RSMK
export PS_FORMAT=pid,stat,tty,bsdstart,bsdtime,%mem,%cpu,command
export JQ_COLORS='36:31:32:34:95:33:35'
export FZF_DEFAULT_OPTS="\
    --color=bg+:#073642,bg:#002b36,spinner:#d33682,hl:#268bd2\
    --color=fg:#839496,header:#586e75,info:#586e75,pointer:#dc322f\
    --color=marker:#cb4b16,fg+:#839496,prompt:#268bd2,hl+:#268bd2\
"

if type rg &>/dev/null; then
    export FZF_DEFAULT_COMMAND='rg --files --hidden'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi

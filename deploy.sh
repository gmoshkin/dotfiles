#!/bin/bash

source utils.sh

function deploy_tmux_conf {
    dir="$(dirname $0)"
    path="$(readlink -f $dir)"
    ln -s "$path/tmux.conf" ~/.tmux.conf
}

function deploy_inputrc {
    dir="$(dirname $0)"
    path="$(readlink -f $dir)"
    ln -s "$path/inputrc" ~/.inputrc
}

function deploy_gdbinit {
    dir="$(dirname $0)"
    path="$(readlink -f $dir)"
    ln -s "$path/gdbinit" ~/.gdbinit
}

function deploy_gtkrc {
    dir="$(dirname $0)"
    path="$(readlink -f $dir)"
    ln -s "$path/gtkrc-2.0" ~/.gtkrc-2.0
}

function deploy_bashrc {
    backup_original ~/.bashrc

    cat ~/.bashrc.original > ~/.bashrc
    cat >> ~/.bashrc << EOF
export DOTFILES="\$HOME/dotfiles"

source "\$DOTFILES/utils.sh"
source "\$DOTFILES/bashrc"
EOF
}

function deploy_dircolors {
    dir="$(dirname $0)"
    path="$(readlink -f $dir)"

    if [ ! -d ~/.dir_colors ]; then
        mkdir ~/.dir_colors
    fi

    ln -s "$path/dircolors" ~/.dir_colors/dircolors
}

function deploy_gitconfig {
    backup_original ~/.gitconfig

    cat ~/.gitconfig.original ./gitconfig > ~/.gitconfig

    dir="$(dirname $0)"
    path="$(readlink -f $dir)"
    ln -s "$path/gitignore" ~/.gitignore
}

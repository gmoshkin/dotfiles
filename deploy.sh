#!/bin/bash

DIRNAME="$(dirname $0)"
CWD="$(readlink -f $DIRNAME)"
HOME=${HOME:-~}

function backup_original {
    if [ ! -f "$1.original" ]; then
        echo "creating '$1.original'"
        if [ -f "$1" ]; then
            cp "$1" "$1.original"
        else
            touch "$1.original"
        fi
        return 0
    else
        echo "'$1.original' already exists, not deploying"
        return 1
    fi
}

function link {
    filename="$1"
    path="${CWD}/$1"
    if [ -n "$2" ]; then
        linkname="$2/$1"
        if [ ! -d "$2" ]; then
            echo "'$2' doesn't exist, creating it"
            mkdir -p "$2"
        fi
    else
        linkname="$HOME/.$1"
    fi
    if [ ! -f "$path" ]; then
        echo "'$path' doesn't exist, not deploying"
        return 1
    fi
    if [ -e "$linkname" ]; then
        echo "'$linkname' already exists, not deploying"
        return 2
    fi
    echo "creating a link '$linkname' -> '$path'"
    ln -s "$path" "$linkname"
}

function deploy_bashrc {
    backup_original ~/.bashrc || return 1
    cat ~/.bashrc.original > ~/.bashrc
    cat >> ~/.bashrc << EOF
export DOTFILES="\$HOME/dotfiles"

source "\$DOTFILES/utils.sh"
source "\$DOTFILES/bashrc"
EOF
}

function deploy_gitconfig {
    backup_original ~/.gitconfig || return 1
    cat ~/.gitconfig.original ./gitconfig > ~/.gitconfig
}

function deploy_dircolors {
    link "dircolors" "~/.dir_colors"
}

function deploy_gdbinit {
    link "gdbinit"
}

function deploy_gitignore {
    link "gitignore"
}

function deploy_gtkrc {
    link "gtkrc-2.0"
}

function deploy_tmux_conf {
    link "tmux.conf"
}

function deploy_inputrc {
    link "inputrc"
}

todeploy=(
    bashrc
    gitconfig
    dircolors
    gdbinit
    gitignore
    gtkrc
    tmux_conf
    inputrc
)

if [ -n "$1" ]; then
    for f in ${todeploy[@]}; do
        if [ "$1" = "$f" ]; then
            echo "Deploying ${f}"
            "deploy_$f"
            exit
        fi
    done
    echo "Unknown module '$1'"
else
    for f in ${todeploy[@]}; do
        echo "Deploying ${f}"
        "deploy_$f"
    done
fi

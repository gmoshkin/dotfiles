#!/bin/bash

set -e

[ -n "$1" ] || { echo "Need a tty as argument"; exit 1; }

pid=$(
    ~/dotfiles/jai/myps --for-fzf -t $1 |
        fzf --ansi --tac --no-sort |
        awk '{ print $1 }'
)

[ -n "$pid" ] || { exit 1; }

exec gdb -p ${pid}

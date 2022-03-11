#!/bin/bash

# set -x
[ -z "$1" ] && exit 1

if [ "$1" = "tmux-serv" ]; then
    PID=$(tmux display -p '#{pid}')
else
    PID=${1}
fi

children() {
    [ -z "$1" ] && return
    ps -e o pid,ppid |  awk '($2 == '$1'){print $1}'
}

descendants() {
    [ -z "$1" -o "$1" == "$$" ] && return
    echo $1
    children $1 |
    while read pid; do
        descendants $pid
    done
}

export FUNCNEST=20

if [ -n "$2" ]; then
    descendants ${PID}
else
    descendants ${PID} | xargs ps f -p
fi
# set +x

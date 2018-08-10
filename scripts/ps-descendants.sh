#!/bin/bash

# set -x
[ -z "$1" ] && exit 1

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

export FUNCNEST=10

if [ -n "$2" ]; then
    descendants $1
else
    descendants $1 | xargs ps f -p
fi
# set +x

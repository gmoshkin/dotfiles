#!/bin/bash

if [ "$1" = -l ]; then
    shift
    out="less"
fi

pane=${1:-$(tmux display -p '#{pane_id}')}
pane_id=$(tmux display -p -t "$pane" '#{pane_id}')
pane_tty=$(tmux display -p -t $pane_id '#{pane_tty}')

if [ "$out" = "less" ]; then
    tmux split-window -t $pane_id "ps-tty.sh $pane_tty | less"
else
    tmux split-window -t $pane_id "watch --color -n1 ps-tty.sh $pane_tty"
fi

#!/bin/bash

ROWS=$(tmux display -p '#{pane_height}')

function list-panes() {
    for t in $(tmux list-panes -a -F '#{pane_tty}'); do
        ps -o pid,stat,tty,bsdstart,bsdtime,command hf -t $t;
    done
}

list-panes | slmenu -l $[ROWS - 1] | awk '{print $3}' | tmux-pane-by-tty.sh - go

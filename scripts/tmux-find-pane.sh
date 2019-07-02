#!/bin/bash

ROWS=$(tmux display -p '#{pane_height}')

function list-panes() {
    for t in $(tmux list-panes -a -F '#{pane_tty}'); do
        ps -o pid,stat,tty,bsdstart,bsdtime,command hf -t $t;
    done
}

function menu() {
    if type fzf &>/dev/null; then
        fzf
    elif type slmenu &>/dev/null; then
        slmenu -l $[ROWS - 1]
    else
        echo 'pls install fzf' >&2
        exit 1
    fi
}

list-panes | menu | awk '{print $3}' | tmux-pane-by-tty.sh - go

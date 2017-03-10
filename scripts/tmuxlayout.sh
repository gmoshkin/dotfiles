#!/bin/bash

function set-window-name {
    if [ -n "$1" ]; then
        tmux rename-window $1
        return 0
    fi
    return -1
}

function split-and-select {
    tmux split-window $1 $2 $3
    tmux select-pane '+'
}

function one-three {
    set-window-name $1
    tmux split-window -v -p 30 \; split-window -h -p 67
    # tmux split-window -h -p 67 -t '+'
    # split-and-select -h -p 50
}

function v-three {
    set-window-name $1
    tmux split-window -h -p 67
    tmux split-window -h -p 50
}

function next-window {
    tmux new-window
    tmux select-window -t ':$'
    if [ -n "$1" ]; then
        "$1" "$2"
    fi
}

# set-window-name "single-pane"

# tmux new-window
# tmux select-window -t ':$'
one-three "vim-window"

# tmux new-window
# tmux select-window -t ':$'
# v-three "three-panes"

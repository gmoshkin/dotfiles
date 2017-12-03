#!/bin/bash

options=
if [ -n "$CMUS_ADDR" ]; then
    options+="--listen $CMUS_ADDR"
fi
pane_height=$(tmux display -p '#{pane_height}')
if [ ! -f /tmp/cover.png ]; then
    if [ -f ~/Pictures/sad.png ]; then
        cp ~/Pictures/sad.png /tmp/cover.png
    fi
fi
tmux split-window -h -l $((pane_height * 2)) ~/dotfiles/scripts/screensaver.py i /tmp/cover.png
tmux split-window -v -t .0 ~/cava/cava
tmux select-pane -t .0
eval "cmus $options"

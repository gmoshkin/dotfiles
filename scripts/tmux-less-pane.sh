#!/bin/bash

pane=${1:-$(tmux display -p '#{pane_id}')}
pane_id=$(tmux display -p -t "$pane" '#{pane_id}')
pane_tty=$(tmux display -p -t $pane_id '#{pane_tty}')

tmux split-window -t $pane_id "ps-tty.sh $pane_tty | less"

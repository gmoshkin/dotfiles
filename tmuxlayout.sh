#!/bin/bash
tmux rename-window "single-pane"

tmux new-window
tmux rename-window "vim-window"
tmux split-window -v -p 30
tmux split-window -h -p 67
tmux split-window -h -p 50

tmux new-window
tmux rename-window "three-panes"
tmux split-window -h -p 67
tmux split-window -h -p 50

tmux select-window -t :1

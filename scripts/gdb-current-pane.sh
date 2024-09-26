#!/bin/bash

set -e
pane=${1:-$(tmux display -p '#{pane_id}')}
pane_id=$(tmux display -p -t "$pane" '#{pane_id}')
pane_tty=$(tmux display -p -t $pane_id '#{pane_tty}')

# I hate this shit, but I need 2 commands to do this, because tmux is shit
exec tmux split-window -t $pane_id gdb-given-pane.sh ${pane_tty}

#!/bin/bash

DELIM=,

[ -z "$1" ] && { echo need a tty; exit 1; }

PANE_ID=$(tmux list-panes -aF "#{pane_id}${DELIM}#{pane_tty}"\
    | grep $1$ | cut -d${DELIM} -f1)

if [ "$2" != go ]; then
    echo $PANE_ID
else
    tmux switch-client -t $(tmux display -pt $PANE_ID '#{session_id}')
    tmux select-window -t $(tmux display -pt $PANE_ID '#{window_id}')
    tmux select-pane -t $PANE_ID
fi

#!/bin/bash

if ! tmux list-sessions &>/dev/null; then
    echo tmux isn\'t running
    exit 1
fi

pane_id=$(tmux list-panes -a -F '#{pane_id};#{pane_current_command}' | \
          grep ';rtorrent' | cut -d';' -f 1)

session_name=rtorrent

if [ -z "$pane_id" ]; then
    echo rtorrent isn\'t started, will try to start it...
    if ! type rtorrent &>/dev/null; then
        echo rtorrent isn\'t installed, can\'t do anything
        exit 2
    fi
    if $(tmux list-sessions -F '#{session_name}' 2>/dev/null | \
         grep "${session_name}" > /dev/null); then
        echo "session '${session_name}' already exists, creating a window"
        tmux new-window -t "${session_name}" "rtorrent"
    else
        echo "session '${session_name}' doesn't exist, creating it"
        tmux new-session -dAs "${session_name}" "rtorrent"
    fi
    if [ $? != 0 ]; then
        echo something went wrong ☹
        exit 3
    fi
    sleep 2 # give the tmux some time to start rtorrent
    echo rtorrent is successfully started
fi

pane_id=$(tmux list-panes -a -F '#{pane_id};#{pane_current_command}' | \
          grep ';rtorrent' | cut -d';' -f 1)

if [ -z "$pane_id" ]; then
    echo still can\'t find rtorrent ☹
    exit 4
fi

debug=0

case "$1" in
    -d | --debug )
        debug=1
        shift
esac

if [ -n "$1" ]; then
    link="$1"
else
    link=$(xsel) || exit 4
fi

if [ $debug != 0 ]; then
    echo tmux send-keys -t "$pane_id" BSpace $link Enter
else
    tmux send-keys -t "$pane_id" BSpace $link Enter
fi

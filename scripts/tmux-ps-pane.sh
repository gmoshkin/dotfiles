#!/bin/bash

case "$1" in
    -?) opt="$1"; shift ;;
esac

pane=${1:-$(tmux display -p '#{pane_id}')}
pane_id=$(tmux display -p -t "$pane" '#{pane_id}')
pane_tty=$(tmux display -p -t $pane_id '#{pane_tty}')

case "$opt" in
    -l) cmd_fmt="%s | less" ;;
    -v) cmd_fmt="%s -C | vim -" ;;
    *)
        exec tmux split-window -t $pane_id ~/dotfiles/jai/pageview -l /tmp/pageview.log ~/dotfiles/jai/ps -t $pane_tty
        ;;
esac

tmux split-window -t $pane_id "$(printf "$cmd_fmt" "ps-tty.sh $pane_tty -t")"

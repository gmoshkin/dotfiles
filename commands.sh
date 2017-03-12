#!/bin/bash

function cathex {
    cat $1 | hexdump -C
}

function body {
    length=$3
    if [ -z "$3" ]; then
        echo '!'
        length="10"
    fi
    head -$(($2 + $length)) $1 | tail -$length
}

function hl {
    $@ --help | less
}

function over {
    local retcode="$?"
    echo "retcode is $retcode"
    zenity --info --text="return code is $retcode" --title="done" 2> /dev/null
}

function T {
    if [ "$1" = "-l" ]; then
        tmux list-sessions
        return
    fi
    if [ -n "$TMUX" ]; then
        return
    fi
    session="${1:-0}"
    if tmux list-sessions | cut -d: -f1 | grep "$session" &> /dev/null; then
        tmux attach -t "$session"
    else
        tmux new -s "$session"
    fi
}

function V {
    local session
    if [ -n "$TMUX" ]; then
        session=$(tmux display-message -p '#{session_name}')
    else
        session="none"
    fi
    local vimservfile="${VIMSERV}_${session}"
    local vimservname="VIM_${session}"
    if [ -f "$vimservfile" ]; then
        vim --servername $vimservname --remote $@
        if [ -n "$TMUX" ]; then
            local window=$(cat "$vimservfile" | cut -d'.' -f 1)
            local pane=$(cat "$vimservfile" | cut -d'.' -f 2)
            tmux select-window -t $window
            tmux select-pane -t $pane
        fi
    else
        touch "$vimservfile"
        if [ -n "$TMUX" ]; then
            local window=$(tmux display-message -p '#{window_index}')
            local pane=$(tmux display-message -p '#{pane_index}')
            echo "$window.$pane" > "$vimservfile"
        fi
        vim --servername $vimservname $@
        rm "$vimservfile"
    fi
}

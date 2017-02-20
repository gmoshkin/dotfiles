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
    if [ -n "$TMUX" ]; then
        return
    fi
    if [ "$1" = "-l" ]; then
        tmux list-sessions
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
    if [ -f "$VIMSERV" ]; then
        vim --remote $@
        if [ -n "$TMUX" ]; then
            window=$(cat "$VIMSERV" | cut -d'.' -f 1)
            pane=$(cat "$VIMSERV" | cut -d'.' -f 2)
            tmux select-window -t $window
            tmux select-pane -t $pane
        fi
    else
        touch "$VIMSERV"
        if [ -n "$TMUX" ]; then
            window=$(tmux display-message -p '#{window_index}')
            pane=$(tmux display-message -p '#{pane_index}')
            echo "$window.$pane" > "$VIMSERV"
        fi
        # vim +'au VimLeave * !rm '$VIMSERV --servername VIM $@
        vim --servername VIM $@
        rm "$VIMSERV"
    fi
}

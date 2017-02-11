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
    zenity --info --text="return code is $?" --title="done"
}

function T {
    if [ -n "$TMUX" ]; then
        return
    fi
    if tmux list-sessions &> /dev/null; then
        tmux attach
    else
        # default amount of panes if it's big enough
        tmux new
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

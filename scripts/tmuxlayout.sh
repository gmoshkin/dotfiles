#!/bin/bash

function get-width {
    echo "$(tmux display -p '#{window_width}')"
}

function main-top {
    tmux\
        split-window -v -p 35 -t ${session_name}:.{bottom-right} \;\
        split-window -h -p 67 -t ${session_name}:.{bottom-right} \;\
        split-window -h -p 50 -t ${session_name}:.{bottom-right}
}

function main-left {
    tmux\
        split-window -h -p 50 -t ${session_name}:.{bottom-right} \;\
        split-window -v -p 50 -t ${session_name}:.{bottom-right}
}

function scalable-layout {
    if [ "$(get-width)" -gt 240 ]; then
        main-top
    else
        main-left
    fi
}

session_name=$2

case "$1" in
    scalable )
        scalable-layout
        ;;
    dots )
        scalable-layout
        ;;
    main-top )
        main-top
        ;;
    main-left )
        main-left
        ;;
    * )
        echo 'unknown parameter'
        ;;
esac

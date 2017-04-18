#!/bin/bash

function get-width {
    echo "$(tmux display -p '#{window_width}')"
}

function main-top {
    tmux\
        split-window -v -p 35 -t .{bottom-right} \;\
        split-window -h -p 67 -t .{bottom-right} \;\
        split-window -h -p 50 -t .{bottom-right}
}

function main-left {
    tmux\
        split-window -h -p 50 -t .{bottom-right} \;\
        split-window -v -p 50 -t .{bottom-right}
}

function dots-layout {
    if [ "$(get-width)" -gt 240 ]; then
        main-top
    else
        main-left
    fi
}

case "$1" in
    dots )
        dots-layout
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

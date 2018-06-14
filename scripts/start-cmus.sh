#!/bin/bash

options=
if [ -n "$CMUS_ADDR" ]; then
    options+="--listen $CMUS_ADDR"
fi

ALBUM_COVER_FILE=/tmp/cover.png
pane_height=$(tmux display -p '#{pane_height}')
if [ ! -f "$ALBUM_COVER_FILE" ]; then
    if [ -f ~/Pictures/sad.png ]; then
        cp ~/Pictures/sad.png "$ALBUM_COVER_FILE"
    else
        echo '<?xml version="1.0" encoding="UTF-8"?>
<svg version="1.1" viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg" xmlns:cc="http://creativecommons.org/ns#" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<ellipse cx="99.576" cy="107.23" rx="50.583" ry="50.265" fill="none" stroke="#000" stroke-width="5.554"/>
<ellipse cx="81.093" cy="94.274" rx="4.1888" ry="4.0297" stroke="#000" stroke-width="5.554"/>
<ellipse cx="118.44" cy="94.349" rx="4.1888" ry="4.0297" stroke="#000" stroke-width="5.554"/>
<path d="m73.892 132.6c11.46-23.221 41.017-22.762 51.544 0.14997l-3.6742 2.004c-12.886-16.081-30.635-15.886-44.271-0.18746z" stroke="#000" stroke-width=".2"/>
</svg>' > /tmp/sad.svg
        PNG_COLOR_TYPE_RGBA=6
        convert \
            -resize 200x200 \
            -extent 400x400 \
            -gravity center \
            -background none \
            -define png:color-type=$PNG_COLOR_TYPE_RGBA \
            /tmp/sad.svg \
            "$ALBUM_COVER_FILE"
    fi
fi
tmux split-window -h -l $((pane_height * 2)) ~/dotfiles/scripts/screensaver.py I "$ALBUM_COVER_FILE"
tmux split-window -v -t .0 ~/cava/cava
tmux select-pane -t .0
eval "cmus $options"

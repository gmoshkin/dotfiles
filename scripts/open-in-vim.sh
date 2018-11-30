#!/bin/bash

source "${DOTFILES}/commands.sh"

filename=$(cat)
if [ "${filename:0:1}" != "/" ]; then
    cwd=$(tmux display -p '#{pane_current_path}')
    filename="${cwd}/${filename}"
fi
V -r "$filename"

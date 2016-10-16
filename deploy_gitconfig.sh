#!/bin/bash

backup_original () {
    if [ ! -f "$1.original" ]; then
        if [ -f "$1" ]; then
            cp "$1" "$1.original"
        else
            touch "$1.original"
        fi
    fi
}

backup_original ~/.gitconfig
backup_original ~/.gitignore

cat ~/.gitconfig.original ./gitconfig > ~/.gitconfig
cat ~/.gitignore.original ./gitignore > ~/.gitignore

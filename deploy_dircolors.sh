#!/bin/bash

source utils.sh

dir="$(dirname $0)"
path="$(readlink -f $dir)"

if [ ! -d ~/.dir_colors ]; then
    mkdir ~/.dir_colors
fi

ln -s "$path/dircolors" ~/.dir_colors/dircolors

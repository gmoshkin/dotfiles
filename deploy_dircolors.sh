#!/bin/bash

source utils.sh

dir="$(dirname $0)"
path="$(readlink -f $dir)"
ln -s "$path/dircolors" ~/.dir_colors/dircolors

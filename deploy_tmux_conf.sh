#!/bin/bash

dir="$(dirname $0)"
path="$(readlink -f $dir)"
ln -s "$path/tmux.conf" ~/.tmux.conf

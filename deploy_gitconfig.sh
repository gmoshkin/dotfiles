#!/bin/bash

source utils.sh

backup_original ~/.gitconfig

cat ~/.gitconfig.original ./gitconfig > ~/.gitconfig

dir="$(dirname $0)"
path="$(readlink -f $dir)"
ln -s "$path/gitignore" ~/.gitignore

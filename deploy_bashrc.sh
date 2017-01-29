#!/bin/bash

source utils.sh

backup_original ~/.bashrc

cat ~/.bashrc.original > ~/.bashrc
cat >> ~/.bashrc << EOF
export DOTFILES="\$HOME/dotfiles"

source "\$DOTFILES/utils.sh"
source "\$DOTFILES/bashrc"
EOF

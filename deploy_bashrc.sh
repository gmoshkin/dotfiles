#!/bin/bash

source utils.sh

backup_original ~/.bashrc

cat ~/.bashrc.original > ~/.bashrc
cat >> ~/.bashrc << EOF
export DOTFILES="\$HOME/dotfiles"

source "\$DOTFILES/bashrc"
source "\$DOTFILES/utils.sh"
EOF

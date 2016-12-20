#!/bin/bash
source ~/dotfiles/utils.sh

USER="$(whoami)"

VIMFILES=${VIMFILES:-"/home/${USER}/.vim"}
if [ -d "$VIMFILES" ]; then
    cd "$VIMFILES"
    find_all > ~/.cache/ctrlp/%home%${USER}%.vim.txt
fi

DOTFILES=${DOTFILES:-"/home/${USER}/dotfiles"}
if [ -d "$DOTFILES" ]; then
    cd "$DOTFILES"
    find_all > ~/.cache/ctrlp/%home%${USER}%dotfiles.txt
fi

REP_DIR=${REP_DIR:-"/space/${USER}/REP"}
if [ -d "$REP_DIR" ]; then
    cd "$REP_DIR"
    find_all > ~/.cache/ctrlp/%space%${USER}%REP.txt
fi

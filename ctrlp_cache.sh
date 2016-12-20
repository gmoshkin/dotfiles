#!/bin/bash
source ~/dotfiles/utils.sh

USER="$(whoami)"
CTRLPCACHE="/home/${USER}/.cache/ctrlp"

VIMFILES=${VIMFILES:-"/home/${USER}/.vim"}
DOTFILES=${DOTFILES:-"/home/${USER}/dotfiles"}
REP_DIR=${REP_DIR:-"/space/${USER}/REP"}
CSPROJ=${CSPROJ:-"/space/${USER}/projects/csharp"}

declare -A CACHE
CACHE=(
    ["$VIMFILES"]="$CTRLPCACHE/%home%${USER}%.vim.txt"
    ["$DOTFILES"]="$CTRLPCACHE/%home%${USER}%dotfiles.txt"
    ["$REP_DIR"]="$CTRLPCACHE/%space%${USER}%REP.txt"
    ["$CSPROJ"]="$CTRLPCACHE/%space%${USER}%projects%csharp.txt"
)

DIRS=(
    "$VIMFILES"
    "$DOTFILES"
    "$REP_DIR"
    "$CSPROJ"
)

for d in ${DIRS[@]}; do
    if [ -d "$d" ]; then
        cd "$d"
        find_all > "${CACHE[$d]}"
    fi
done

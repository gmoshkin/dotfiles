#!/bin/bash
source ~/dotfiles/utils.sh

USER="$(whoami)"
CTRLPCACHE="/home/${USER}/.cache/ctrlp"

VIMFILES=${VIMFILES:-"/home/${USER}/.vim"}
DOTFILES=${DOTFILES:-"/home/${USER}/dotfiles"}
REP_DIR=${REP_DIR:-"/space/${USER}/REP"}
CSPROJ=${CSPROJ:-"/space/${USER}/projects/csharp"}
PRS=${PRS:-"/space/${USER}/PRs"}

declare -A CACHE
CACHE=(
    ["$VIMFILES"]="$CTRLPCACHE/%home%${USER}%.vim.txt"
    ["$DOTFILES"]="$CTRLPCACHE/%home%${USER}%dotfiles.txt"
    ["$REP_DIR"]="$CTRLPCACHE/%space%${USER}%REP.txt"
    ["$CSPROJ"]="$CTRLPCACHE/%space%${USER}%projects%csharp.txt"
    ["$PRS"]="$CTRLPCACHE/%space%${USER}%PRs.txt"
)

# in order to update the cache for just one directory, comment out the rest of
# them in this array
DIRS=(
    "$VIMFILES"
    "$DOTFILES"
    "$REP_DIR"
    "$CSPROJ"
    "$PRS"
)

for d in ${DIRS[@]}; do
    if [ -d "$d" ]; then
        cd "$d"
        find_all > "${CACHE[$d]}"
    fi
done

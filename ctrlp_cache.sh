#!/bin/bash
source ~/dotfiles/utils.sh

CTRLPCACHE=~/.cache/ctrlp
DIRSLISTFILE=~/.config/ctrlp_cache_dirs

# XXX won't work if you put spaces in directory names so don't do it
for d in $(cat $DIRSLISTFILE); do
    # this expands '~' to home directory, don't you just love bash?
    eval d=$d
    f="${CTRLPCACHE}/$(echo $d | sed 's/\/\//\//g' | sed 's/\//%/g').txt"

    if [ -d "$d" ]; then
        echo "Searching files for '$d'"
        cd "$d"
        find_all > "$f"
        echo "Done. Written to '$f'"
    fi
done

#!/usr/bin/env bash

if [ -z "$1" ]; then
    exit -1
fi

needed="$1"
version=$(tmux -V | cut -d' ' -f2 | cut -d'-' -f1)
# the result of the script would be true if version >= needed
case "${version}" in
    (master|next) exit 0;;
    (*) exit $(echo "${version}<${needed}" | bc)
esac

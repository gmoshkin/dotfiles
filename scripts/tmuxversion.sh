#!/usr/bin/env bash

if [ -z "$1" ]; then
    exit -1
fi

needed="$1"
version=$(tmux -V | cut -d' ' -f2)
# the result of the script would be true if version >= needed
if [ "${version}" = master ]; then
    exit 0
else
    exit $(echo "${version}<${needed}" | bc)
fi

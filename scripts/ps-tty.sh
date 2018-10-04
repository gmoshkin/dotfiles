#!/bin/bash

[ -z "$1" ] && exit 1
TTY=${1}

hl_executable() {
    sed 's/\(\\_\s\+\)\([^ ]\+\)/\1[35m\2[0m/'
}
hl_python_arg() {
    sed 's/\(\\_\s\+\)\([^ ]*python[^ ]*\)\s\+\([^ ]\+\)/\1\2 [34m\3[0m/'
}
ps f -t $TTY | hl_executable | hl_python_arg

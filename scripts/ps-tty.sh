#!/bin/bash

[ -z "$1" ] && exit 1
TTY=${1}

hl_executable() {
    sed 's/\(\\_\s\+\)\([^ ]\+\)/\1[35m\2[0m/'
}
hl_interp_arg() {
    sed 's/\(\\_\s\+\)\([^ ]*\(python\|bash\)[^ ]*\)\s\+\([^ ]\+\)/\1\2 [34m\4[0m/'
}
ps f -t $TTY | hl_executable | hl_interp_arg

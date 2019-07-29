#!/bin/bash

[ -z "$1" ] && exit 1
TTY=${1}

hl_executable() {
    sed 's/\(\\_\s\+\)\([^ ]\+\)/\1[35m\2[0m/'
}
hl_interp_arg() {
    sed 's/\(\\_\s\+\)\([^ ]*\(python\|bash\)[^ ]*\)\s\+\([^ ]\+\)/\1\2 [34m\4[0m/'
}

{
    if [ "$2" = '-t' ]; then
        shift
        ps hf -o pid -t $TTY | head | {
            read rpid
            ps-descendants.sh $rpid
        }
    else
        ps f -t $TTY;
    fi
} | {
    if [ "$2" = '-C' ]; then
        cat
    else
        hl_executable | hl_interp_arg
    fi
}

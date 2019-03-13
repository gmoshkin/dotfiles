#!/bin/bash

[ -z "$1" ] && exit 1
TTY=${1}
ps f -t $TTY | sed 's/\(\\_\s\+\)\([^ ]\+\)/\1[35m\2[0m/'

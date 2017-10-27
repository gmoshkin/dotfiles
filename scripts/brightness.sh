#!/bin/bash

function __set {
    if [ "$1" -gt 0 ]; then
        echo $1
        xbacklight -set "$1"
    else
        echo 1
        xbacklight -set 1
    fi
}

argument="$1"
DEFAULT_OFS="10"
ABSOLUTE='^[0-9]+$'
RELATIVE='^[+-][0-9]+$'
DEFAULT='[-+]'
new=
current=$(xbacklight -get | cut -d. -f1 | python -c 'print(int(round(float(input()))))')
if [[ "${argument}" =~ ${ABSOLUTE} ]]; then
    new=${argument}
    __set ${new}
elif [[ "${argument}" =~ ${RELATIVE} ]]; then
    new=$(eval 'echo $(('"${current}${argument}"'))')
    __set ${new}
elif [[ "${argument}" =~ ${DEFAULT} ]]; then
    offset="${argument}${DEFAULT_OFS}"
    new=$(eval 'echo $(('"${current}${offset}"'))')
    __set ${new}
else
    echo "${current}"
fi


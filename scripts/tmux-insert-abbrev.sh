#!/bin/bash

match_default() {
    declare -A ABBREVS=(
        ['pi']='π'
        ['ta']='τ'
        ['!=']='≠'
        ['>=']='≥'
        ['<=']='≤'
        ['*8']='∞'
        ['*x']='×'
        ['>>']='»'
        ['<<']='«'
        ['..']='…'
        [':(']='☹'
        [':)']='☺'
        ['(e']='∈'
        ['e)']='∋'
        ['(c']='⊂'
        ['c)']='⊃'
        ['(<']='⊂'
        ['(>']='⊃'
        ['(&']='∩'
        ['(|']='∪'
        ['zw']='​'
    )
    tmux send-keys ${ABBREVS["$1"]}
}

match_script() {
    kind="$1"
    target="$2"
    SUBSUPERSCRIPTSFILE="$HOME/dotfiles/subsuperscripts.json"
    if [ -f "$SUBSUPERSCRIPTSFILE" ]; then
        <$SUBSUPERSCRIPTSFILE \
            jq -r ".${kind}|to_entries[]|[.key,.value.unicode]|@tsv" |
            while read key val; do
                if [ "$key" = "$target" ]; then
                    tmux send-keys "$val"
                    exit 0
                fi
            done
    fi
}

case "$1" in
    ('^') match_script superscript "$2" ;;
    ('_') match_script subscript "$2" ;;
      (*) match_default "${1}${2}" ;;
esac

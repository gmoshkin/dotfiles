#!/bin/bash

function cathex {
    cat $1 | hexdump -C
}

function body {
    length=$3
    if [ -z "$3" ]; then
        echo '!'
        length="10"
    fi
    head -$(($2 + $length)) $1 | tail -$length
}

function hl {
    $@ --help | less
}

function __retcode_message {
    retcode="$?"
    if [ -n "$1" ]; then
        retcode="$1"
    fi
    if [ "$retcode" = 0 ]; then
        status="SUCCESS"
    else
        status="FAIL"
    fi
    message="Process ${status} (${retcode})"
    echo $message
}

function over {
    local message=$(__retcode_message)
    if [ -n "$1" ]; then
        message="$1"
    fi
    echo $message
    zenity --info --text="$message" --title="done" 2> /dev/null
}

function T {
    if [ "$1" = "-l" ]; then
        tmux list-sessions
        return
    fi
    if [ -n "$TMUX" ]; then
        return
    fi
    session="${1:-0}"
    if tmux list-sessions | cut -d: -f1 | grep "$session" &> /dev/null; then
        tmux attach -t "$session"
    else
        tmux new -s "$session"
    fi
}

function V {
    local only_remote
    if [ "$1" = '-r' ]; then
        only_remote=1
        shift
    fi
    local session
    if [ -n "$TMUX" ]; then
        session=$(tmux display-message -p '#{session_name}')
    else
        session="none"
    fi
    local vimservfile="${VIMSERV}_${session}"
    local vimservname="VIM_${session}"
    if [ -f "$vimservfile" ]; then
        if [[ "$1" =~ :[0-9]+$ ]]; then
            local file="$(echo "$1" | sed 's/:[0-9]\+$//')"
            local lineno="$(echo "$1" | sed 's/^.*:\([0-9]\+\)$/+\1/')"
            vim --servername $vimservname --remote "$lineno" "$file"
        else
            vim --servername $vimservname --remote "$@"
        fi
        if [ -n "$TMUX" ]; then
            local window=$(cat "$vimservfile" | cut -d'.' -f 1)
            local pane=$(cat "$vimservfile" | cut -d'.' -f 2)
            tmux select-window -t $window
            tmux select-pane -t $pane
        fi
    elif [ -z "${only_remote}" ]; then
        touch "$vimservfile"
        if [ -n "$TMUX" ]; then
            local window=$(tmux display-message -p '#{window_index}')
            local pane=$(tmux display-message -p '#{pane_index}')
            echo "$window.$pane" > "$vimservfile"
        fi
        vim --servername $vimservname "$@"
        rm "$vimservfile"
    fi
}

function weather {
    curl "http://wttr.in/${1:-Moscow}"
}

function volume {
    local DEFAULT_OFS="5"
    local argument="$1"
    local ABSOLUTE='^[0-9]+$'
    local ABSOLUTE_PERC='^[0-9]+%$'
    local RELATIVE='^[+-][0-9]+$'
    local DEFAULT='[-+]'
    local new
    local current=$(amixer get Master | grep '%' | cut -d'[' -f2 | cut -d'%' -f1)
    if [[ "${argument}" =~ ${ABSOLUTE} || "${argument}" =~ ${ABSOLUTE_PERC} ]]; then
        new=${argument}
        amixer -q set Master ${new}
    elif [[ "${argument}" =~ ${RELATIVE} ]]; then
        new=$(eval 'echo $(('"${current}${argument}"'))')
        amixer -q set Master ${new}%
    elif [[ "${argument}" =~ ${DEFAULT} ]]; then
        local offset="${argument}${DEFAULT_OFS}"
        new=$(eval 'echo $(('"${current}${offset}"'))')
        amixer -q set Master ${new}%
    else
        echo "${current}"
    fi
}

function bool {
    $@ && echo 'True' || echo 'False'
}

function integram {
    local token=""
    if [ "$1" == -t -o "$1" == --token ]; then
        token="$2"
        shift; shift
    else
        if [ -z "$INTEGRAM_TOKEN" ]; then
            echo "Please set the INTEGRAM_TOKEN variable"
            return -1
        else
            token="$INTEGRAM_TOKEN"
        fi
    fi
    local message=""
    if [ "$1" == - ]; then
        while read -r line; do
            quoted=$(echo $line | sed 's/"/\\"/g')
            echo $quoted'\n'
            message+=$quoted'\n'
        done
    else
        message="$@"
    fi
    message=$(echo "$message" | sed 's/>/＞/g')
    data='payload={"text":"'"$message"'"}'
    curl -s -d "$data" "https://integram.org/$token"
}

function eda {
    integram --token $EDA_INTEGRAM_TOKEN $@
}

function tover {
    local message=$(__retcode_message)
    if [ -n "$1" ]; then
        message="$1"
    fi
    over "$message" &
    integram "$message" &
}

function whatthecommit {
    curl -s http://whatthecommit.com/index.txt
}

function Os {
    xdg-open "$1" 2>/dev/null
}

function M {
    vim "+M $@"
}

complete -F _man M

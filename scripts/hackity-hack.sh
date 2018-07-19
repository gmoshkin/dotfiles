#!/bin/bash

before_exit () {
    tput rmcup
    tput cnorm
    exit
}

trap before_exit SIGINT

bufname="${TMUX_PANE}-screen"
buffilename=$(mktemp)
tmux capture-pane -et $TMUX_PANE -b "$bufname"
tmux save-buffer -b "$bufname" $buffilename
tput smcup
tput civis
cat $buffilename
sleep .5
tput cup $(( $(tput lines) / 2 )) $(( $(tput cols) / 2 - 10 ))
tput setaf 1
tput setab 7

sleep .5
echo -n 'H'
sleep .5
echo -n 'E'
sleep .5
echo -n 'L'
sleep .5
echo -n 'L'
sleep .5
echo -n 'O'
sleep .5
echo -n '!'

read -rsn1

before_exit

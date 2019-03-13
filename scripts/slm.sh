#!/bin/bash

tput smcup
ls | slmenu -l ${LINES:-$(tmux display -p '#{pane_height}')} | xargs less
tput rmcup

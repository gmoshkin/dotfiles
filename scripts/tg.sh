#!/bin/bash

source $DOTFILES/colors.sh

TG=$HOME/tg/bin/telegram-cli

case $1 in
    "unread")
        $TG -e dialog_list 2> /dev/null | grep -v '0 unread' | grep 'unread'
        echo -n $CLRRESET
        ;;
    *)
        echo 'unknown command'
        ;;
esac

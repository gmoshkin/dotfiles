#!/usr/bin/env bash

if [ "$1" == "hide" ]; then
    i3-msg [class="TelegramDesktop"] move scratchpad
    i3-msg mode "default"
else
    if xdotool search --class TelegramDesktop; then
        i3-msg [class="TelegramDesktop"] scratchpad show
    else
        i3-msg exec ~/Telegram/Telegram
        i3-msg mode "telegram"
    fi
fi

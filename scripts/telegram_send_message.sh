#!/usr/bin/bash

die() {
    echo "$@" >&2
    exit 1
}

if [ "$1" = "chat" ]; then
    [ -n "$2" ] || die "expected a chat id after 'chat'"
    CHAT_ID="$2"
    shift
    shift
else
    CHAT_ID=$CHAT_ID_ME
fi

[ -n "$1" ] || die "expected message text as arguments"

MESSAGE=$(echo "$@" | jq -Rr @uri)

curl -X POST \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage?chat_id=${CHAT_ID}&text=${MESSAGE}" \
    | jq

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

[ -n "$1" ] || die "expected a filepath as first argument"
FILEPATH="$(realpath $1)"
CAPTION=${2-$(basename $1)}

curl -X POST \
    -F "document=@${FILEPATH}" \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument?chat_id=${CHAT_ID}&caption=${CAPTION}" \
    | jq

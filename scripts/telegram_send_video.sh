#!/usr/bin/bash

set -e

FILEPATH="$(realpath $1)"
CAPTION=$(basename $1)

DIMENSIONS=$(
    ffprobe -v quiet -of json -show_streams "$FILEPATH" |
        jq -r '.streams[] | select(.width != null) | "width=\(.width)&height=\(.height)&duration=\(.duration)"'
)
RESPONSE=$(
    curl -X POST \
        -F "video=@$FILEPATH" \
        "https://api.telegram.org/bot${GMOSHKINBOT_TOKEN}/sendVideo?chat_id=${CHAT_ID_SP}&caption=${CAPTION}&${DIMENSIONS}&supports_streaming=True"
)
echo $RESPONSE | jq
[ "$(echo "$RESPONSE" jq -r '.ok')" = true ]

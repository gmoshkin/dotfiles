FILE="$1"
WIDTH=960
HEIGHT=540
DURATION=$[22 * 60 + 05]
curl -X POST \
    -F "video=@./$FILE" \
    "https://api.telegram.org/bot${GMOSHKINBOT_TOKEN}/sendVideo?chat_id=${CHAT_ID_SP}&caption=${FILE}&width=${WIDTH}&height=${HEIGHT}&duration=${DURATION}&supports_streaming=True" \
    | jq

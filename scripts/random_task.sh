#!/bin/bash

if [ -z "$KEY" -o -z "$TOK" -o -z "$BID" ]; then
    echo "KEY, TOK, BID vars aren't set (see ~/.config/trello-api-keys.conf)"
    exit 1
fi

curl "https://api.trello.com/1/boards/${BID}/lists?filter=open&cards=open&key=${KEY}&token=${TOK}" |
    jq '.[].cards|.[].name' -r | shuf | head -1

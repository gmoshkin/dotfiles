#!/usr/bin/bash

curl "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getUpdates" | jq

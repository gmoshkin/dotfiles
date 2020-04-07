#!/usr/bin/env bash

curl -s 'https://pomber.github.io/covid19/timeseries.json' |
    jq -r '.Russia[-1]|"\(.confirmed)/\(.deaths)/\(.recovered)"'

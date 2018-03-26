#!/bin/bash

crontab -l > ".crontab.$(date +'%Y%m%d%H%M%S').bak"

{
    crontab -l | sed '/\S\+\s\+\S\+\s\+\S\+\s\+\S\+\s\+\S\+\s\+~\/dotfiles\/scripts\/alarm\.sh/ d';
    alarms_to_cron.py -o 0 -r '~/dotfiles/scripts/alarm.sh' -p '#---{ ALARMS }---#';
} | tr '\n' '\n' | crontab -

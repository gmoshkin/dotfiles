#!/bin/sh

# Turn your computer into a digital radio alarm clock.
# Use cron to schedule the script to trigger at the designated
# date and time of your choosing.

# Change the following URL to your choice of online stream
STREAMING_ADDRESS=http://eradioportal.com/monsterRx.asx
STREAMING_ADDRESS=http://23.92.61.218:80

# Mute the speakers.  You don't want to be rudely awakened
# by a sudden rush of sound from the speakers now, do you?
amixer -q set Master 0

# Let's use VLC to stream content.
case "$1" in
    "local" )
        cd /media/gmoshkin/56BE0E36BE0E0EE5/Users/mgn/Music
        DISPLAY=:0 mpg321 -@ shuffled -Z &
        ;;
    "radio" | * )
        DISPLAY=:0 cvlc $STREAMING_ADDRESS &
        ;;
esac
# sleep 10  # A 10-second wait should be enough time to fill up the buffer.

# Gradually turn the volume up in 5% increments every 2 seconds
for STEP in `seq 0 2 50`
do
    amixer -q set Master $STEP%
    sleep 1
done

# EOF

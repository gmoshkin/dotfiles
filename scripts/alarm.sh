#!/bin/bash

# Turn your computer into a digital radio alarm clock.
# Use cron to schedule the script to trigger at the designated
# date and time of your choosing.

# Change the following URL to your choice of online stream
STREAMING_ADDRESS=http://eradioportal.com/monsterRx.asx
STREAMING_ADDRESS=http://23.92.61.218:80
STREAMING_ADDRESS=http://streaming.streamonomy.com/keepfree60s

# Mute the speakers.  You don't want to be rudely awakened
# by a sudden rush of sound from the speakers now, do you?
amixer -q set Master 0

# Not sure if this is persistent, but this is what $XDG_RUNTIME_DIR/cmus-socket
# is at the time of me running it
CMUS_SOCKET="/run/user/1000/cmus-socket"
CMUS_REMOTE="cmus-remote --server $CMUS_ADDR --passwd $CMUS_PWD"
export USER=gmoshkin

function start_cmus {
    $CMUS_REMOTE -C "set shuffle=true" &> /tmp/cmus.out
    $CMUS_REMOTE -C "set aaa_mode=all" &>> /tmp/cmus.out
    $CMUS_REMOTE --play &>> /tmp/cmus.out
}

function try_start_cmus {
    if ! tmux list-sessions >/dev/null; then
        echo "tmux isn't running"
        return 1
    fi
    echo "opening music session..."
    tmux new-session -dAs music "~/dotfiles/scripts/start-cmus.sh"
    sleep 3
}

function try_cmus {
    if ! $CMUS_REMOTE -C format_print &>/dev/null; then
        echo "cmus isn't running"
        if ! try_start_cmus; then
            echo "failed to run cmus"
            echo no
            return 1
        fi
    fi
    echo yes
    start_cmus
    return 0
}

# Let's use VLC to stream content.
export DISPLAY=:0
case "$1" in
    "local" )
        cd /media/gmoshkin/56BE0E36BE0E0EE5/Users/mgn/Music
        DISPLAY=:0 mpg321 -@ shuffled -Z &
        ;;
    "cmus" )
        start_cmus &
        ;;
    "radio" | * )
        try_cmus || cvlc $STREAMING_ADDRESS &
        ;;
esac
# sleep 10  # A 10-second wait should be enough time to fill up the buffer.

echo volume
# Gradually turn the volume up in small increments every some seconds
start_vol=0
vol_step=2
end_vol=78
step_duration=1
for STEP in `seq $start_vol $vol_step $end_vol`
do
    amixer -q set Master $STEP%
    sleep $step_duration
done

# EOF

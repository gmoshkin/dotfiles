#!/bin/bash
config=~/.config/home-music-conf
if [ ! -f $config ]; then
    echo $config doesn\'t exist, please create it
    exit 1
fi

source $config

if [ -z "$HOME_PORT" -o -z "$HOME_USER" -o -z "$HOME_HOST" -o -z "$HOME_MUSIC_PATH" \
    -o -z "$LOCAL_MUSIC_PATH" ]; then
    echo variables HOME_PORT HOME_USER HOME_HOST HOME_MUSIC_PATH LOCAL_MUSIC_PATH \
        must be set
    exit 2
fi

sudo sshfs -p $HOME_PORT -o allow_other -o IdentityFile=~/.ssh/id_rsa $HOME_USER@$HOME_HOST:$HOME_MUSIC_PATH $LOCAL_MUSIC_PATH

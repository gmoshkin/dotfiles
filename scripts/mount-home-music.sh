#!/bin/bash
sshfs -p $HOME_PORT -o allow_other -o IdentityFile=~/.ssh/id_rsa $HOME_USER@$HOME_HOST:$HOME_MUSIC_PATH $LOCAL_MUSIC_PATH

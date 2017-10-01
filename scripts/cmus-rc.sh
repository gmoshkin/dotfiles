#!/usr/bin/env bash

parse_artist_title() {
    awk -e '
        $2 == "artist" {
            artist = "";
            for ( i = 3; i <=NF; i++ )
                artist = artist $i " ";
        }
        $2 == "title" {
            title = "";
            for ( i = 3; i <=NF; i++ )
                title = title $i " ";
        }
        $1 == "status" {
            status = ($2 == "playing") ? "▶️" : "⏸"
        }
        END {
            print status " " artist "- " title
        }
    '
}

parse_setting() {
    setting="$1"
    awk -e '
        $2 == "'"$1"'" {
            setting = ($3 == "true") ? ("on") : ("off");
        }
        END {
            print "'"$1"' is " setting
        }
    '
}

parse_aaa_mode() {
    awk -e '
        $2 == "artist" {
            artist = "";
            for ( i = 3; i <= NF; i++ )
                artist = artist $i " ";
        }
        $2 == "album" {
            album = "";
            for ( i = 3; i <=NF; i++ )
                album = album $i " ";
        }
        $2 == "aaa_mode" {
            aaa_mode = $3
        }
        END {
            if ( aaa_mode == "artist" ) {
                printf("playing songs from artist %s\n", artist)
            } else if ( aaa_mode == "album" ) {
                printf("playing songs from album %s\n", album)
            } else if ( aaa_mode == "all" ) {
                print "playing all songs"
            } else {
                print "i don'"'"'t know what were'"'"' playing"
            }
        }
    '
}

source ~/.cmus-vars
alias cmus-remote="cmus-remote --server $CMUS_ADDR --passwd $CMUS_PWD"

set_aaa_mode() {
    mode="$1"
    cmus-remote -C "set aaa_mode=$1"
    cmus-remote -Q | parse_aaa_mode
}

case "$1" in
    next )
        cmus-remote -n
        ;;
    prev )
        cmus-remote -p
        ;;
    pause )
        cmus-remote -u
        ;;
    parse )
        parse_artist_title
        ;;
    shuffle )
        cmus-remote --shuffle
        cmus-remote -Q | parse_setting shuffle
        ;;
    repeat-cur )
        cmus-remote -C "toggle repeat_current"
        cmus-remote -Q | parse_setting repeat_current
        ;;
    artist | album | all )
        set_aaa_mode $1
        ;;
    now )
        cmus-remote -Q | parse_artist_title
        ;;
esac

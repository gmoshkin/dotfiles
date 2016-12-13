source $DOTFILES/colors.sh

function appendToPath {
    if [[ "$PATH" != *"$1"* ]]; then
        export PATH="${PATH}:$1"
    fi
}

function prependToPath {
    if [[ "$PATH" != *"$1"* ]]; then
        export PATH="$1:${PATH}"
    fi
}

function cathex {
    cat $1 | hexdump -C
}

function body {
    length=$3
    if [ -z "$3" ]; then
        echo '!'
        length="10"
    fi
    head -$(($2 + $length)) $1 | tail -$length
}

function hl {
    $@ --help | less
}

function over {
    zenity --info --text="return code is $?" --title="done"
}

backup_original () {
    if [ ! -f "$1.original" ]; then
        if [ -f "$1" ]; then
            cp "$1" "$1.original"
        else
            touch "$1.original"
        fi
    fi
}

function T {
    if [ -n "$TMUX" ]; then
        return
    fi
    if tmux list-sessions &> /dev/null; then
        tmux attach
    else
        tmux new
    fi
}

function pane_width {
    echo $(tmux display-message -p '#{pane_width}')
}

function line {
    # ┌┐┍┑┎┒┏┓╭╮
    # └┘┕┙┖┚┗┛╰╯
    # ┬─┬
    # ├┼┤
    # ┴│┴
    # ⑉
    echo $(echo 'print "\xe2\x94\x80"*('$1'-2)' | python)
}

function fancy_prompt {
    local P
    P+="╭─("
    # P+="╭$(line $(pane_width))╮\n"
    P+='${debian_chroot:+($debian_chroot)}'
    P+='\['$CLRFGGREEN'\]'
    P+="$(whoami)@"
    P+='\['$CLRFGYELLOW'\]'
    P+="$(hostname)"
    P+='\['$CLRRESET'\]'
    P+=':'
    P+='\['$CLRFGBLUE'\]'
    P+="$(pwd)"
    P+='\['$CLRRESET'\]'
    P+=")───────────────────────────────────────────────("
    P+="$(date +'%a %d %b %Y %H:%M')"
    P+=")"
    P+='\n'
    P+='╰─'
    # display a dollar symbol in blue color at newline
    P+='\[\033[00m\]\$'
    echo -e $P
}

function simple_prompt {
    local P
    P+='${debian_chroot:+($debian_chroot)}'
    # display username in green color
    P+='\[\033[32m\]\u'
    # display hostname in yellow color
    P+='@\[\033[33m\]\h'
    # display a colon in default color
    P+='\[\033[00m\]:'
    # display working directory in blue color
    P+='\[\033[34m\]\w'
    # display a dollar symbol in blue color
    P+='\[\033[00m\]\$'
    echo -e $P
}

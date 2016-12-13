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

function columns {
    if [ -n "$TMUX" ]; then
        echo $(tmux display-message -p '#{pane_width}')
    else
        echo $(tput cols)
    fi
}

function fancy_prompt {
    local P
    P+='$($DOTFILES/prompt.py $(columns) $(whoami) $(hostname) $(pwd) $(date +"%a %d %b %Y %H:%M"))'
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

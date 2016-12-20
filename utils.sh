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

function V {
    if [ -f "$VIMSERV" ]; then
        vim --remote $@
        if [ -n "$TMUX" ]; then
            window=$(cat "$VIMSERV" | cut -d'.' -f 1)
            pane=$(cat "$VIMSERV" | cut -d'.' -f 2)
            tmux select-window -t $window
            tmux select-pane -t $pane
        fi
    else
        touch "$VIMSERV"
        if [ -n "$TMUX" ]; then
            window=$(tmux display-message -p '#{window_index}')
            pane=$(tmux display-message -p '#{pane_index}')
            echo "$window.$pane" > "$VIMSERV"
        fi
        # vim +'au VimLeave * !rm '$VIMSERV --servername VIM $@
        vim --servername VIM $@
        rm "$VIMSERV"
    fi
}

function columns {
    if [ -n "$TMUX" ]; then
        tmux_cols=$(tmux display-message -p '#{pane_width}')
    fi
    tput_cols=$(tput cols)
    echo "$tput_cols"
}

function separator {
    width=$(( $1 - ${#2} - ${#3} - ${#4} - ${#5} - 7 ))
    echo 'print "\xe2\x94\x80" * '$width | python
}

function fancy_prompt {
    local P
    sep='$(separator $(columns) $(whoami) $(hostname) $(pwd) $(date +"%a_%d_%b_%Y_%H:%M"))'

    SEPCLR='\[\033[30m\]'
    DOLLARCLR='\[\033[92m\]'
    COLONCLR='\[\033[30m\]'
    RESETCLR='\[\033[00m\]'
    UNAMECLR='\[\033[32m\]'
    HNAMECLR='\[\033[33m\]'
    DATECLR='\[\033[32m\]'
    CWDCLR='\[\033[34m\]'

    P+=$SEPCLR'╭'
    P+=$SEPCLR'('
    P+=$UNAMECLR'$(whoami)@'
    P+=$HNAMECLR'$(hostname)'
    P+=$COLONCLR':'
    P+=$CWDCLR'$(pwd)'
    P+=$SEPCLR')'
    P+=$SEPCLR$sep
    P+=$SEPCLR'('
    P+=$DATECLR'$(date +"%a %d %b %Y %H:%M")'
    P+=$SEPCLR')'
    P+='\n'
    P+=$SEPCLR'╰'
    P+=$DOLLARCLR'\$'
    P+=$RESETCLR
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
    # display a dollar symbol in default color
    P+='\[\033[00m\]\$'
    echo $P
}

function cut_dir {
    sed 's/^\.\/\?//'
}

function sort_len {
    awk '{ print length, $0  }' | sort -n | cut -d' ' -f2-
}

function debug {
    >&2 echo "$@"
}

function read_local_ignore {
    local IGNOREFILE=".ctrlpignore"
    if [ ! -f "$IGNOREFILE" ]; then
        return
    fi
    local local_dirs
    IFS=$'\r\n' GLOBIGNORE='*' command eval 'local_dirs=($(cat $IGNOREFILE))'
    local ignore
    ignore=""
    for d in "${local_dirs[@]}"; do
        ignore="$ignore -o -path '${d}'"
    done
    echo "$ignore"
}

function find_all {
    ignore_names=(
        '*.tar.gz'
        '*.class'
        '*.swp'
        '*.png'
        '*.jpg'
        '*.gif'
        '*.zip'
        '*.rar'
        '*.exe'
        '*.jar'
        '*.war'
        '*.pyc'
        '*.so'
        '*.db'
        '*.o'
        '*.d'
        '.*'
    )
    ignore_dirs=(
        '*/.git'
    )
    ignore=""
    for d in "${ignore_dirs[@]}"; do
        ignore="$ignore -o -path '${d}'"
    done
    ignore="$ignore $(read_local_ignore)"
    for n in "${ignore_names[@]}"; do
        ignore="$ignore -o -name '${n}'"
    done
    # remove the leading '-o'
    ignore=$(echo "$ignore" | cut -d' ' -f3-)
    # echo "$ignore"
    # echo find . -mindepth 1 \( $ignore \) -prune -o -type f -print
    # echo "find . -mindepth 1 \( $ignore \) -prune -o -type f -print"
    eval "find . -mindepth 1 \( $ignore \) -prune -o -type f -print | cut_dir | sort_len"
}

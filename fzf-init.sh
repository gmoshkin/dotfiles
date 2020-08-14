[ -z "$HOME" ] && { echo "HOME isn't set, wtf?"; return 1; }

# Setup fzf
# ---------
if [[ ! "$PATH" == *${HOME}/.fzf/bin* ]]; then
    export PATH="${PATH:+${PATH}:}${HOME}/.fzf/bin"
fi

try_source() {
    [ -f "$1" ] && {
        # echo $1 exists
        source "$1" 2> /dev/null;
    }
}

for dir in "/usr/share/doc/fzf/examples" "${HOME}/.fzf/shell"; do
    # Auto-completion
    # ---------------
    [[ $- == *i* ]] && try_source "${dir}/completion.zsh"

    # Key bindings
    # ------------
    try_source "${dir}/key-bindings.zsh"
done
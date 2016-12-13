# disable c-s binding (stop/start output control)
stty -ixon

# color_prompt
case "$TERM" in
    *color) PS1="$(fancy_prompt) ";;
    # *color) PS1="$(simple_prompt) ";;
esac


# tmux pwd fix
# PS1='$([ -n "$TMUX" ] && tmux setenv TMUXPWD_$(tmux display -p "#D" | tr -d %) "$PWD")'"$PS1"

# Emacs style key-bindings
# gsettings set org.gnome.desktop.interface gtk-key-theme "Emacs"

export EDITOR="$(which vim)"
export GDBHISTFILE="$HOME/.gdb_history"

alias watch='watch --color -n 1'
alias cput='xsel --clipboard'
alias cget='cat | xsel --clipboard'

# check if `thefuck` is installed and make an alias for it
if type "thefuck" > /dev/null; then
    eval $(thefuck -a)
fi

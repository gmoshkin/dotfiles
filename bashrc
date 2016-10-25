# disable c-s binding (stop/start output control)
stty -ixon

# color_prompt
case "$TERM" in
    *color) PS1='${debian_chroot:+($debian_chroot)}\[\033[32m\]\u@\[\033[33m\]\h\[\033[00m\]:\[\033[34m\]\w\[\033[00m\]\$ ';;
esac


# tmux pwd fix
PS1="$PS1"'$([ -n "$TMUX" ] && tmux setenv TMUXPWD_$(tmux display -p "#D" | tr -d %) "$PWD")'

# Emacs style key-bindings
# gsettings set org.gnome.desktop.interface gtk-key-theme "Emacs"

export EDITOR="$(which vim)"

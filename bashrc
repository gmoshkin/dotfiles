# disable c-s binding (stop/start output control)
stty -ixon

source "$DOTFILES/utils.sh"

PROMPT=${PROMPT:-fancy}
# color_prompt
if [[ "$TERM" == *color ]]; then
    case "$PROMPT" in
        "python")
            PS1="$(python_prompt) ";;
        "fancy")
            PS1="$(fancy_prompt) ";;
        *)
            PS1="$(simple_prompt) ";;
    esac
fi


# tmux pwd fix
# PS1='$([ -n "$TMUX" ] && tmux setenv TMUXPWD_$(tmux display -p "#D" | tr -d %) "$PWD")'"$PS1"

# Emacs style key-bindings
# gsettings set org.gnome.desktop.interface gtk-key-theme "Emacs"

source "$DOTFILES/env.sh"
source "$DOTFILES/aliases.sh"

export HISTSIZE=-1 # infinite
export HISTFILESIZE=-1 # infinite

# check if `thefuck` is installed and make an alias for it
if type "thefuck" &> /dev/null; then
    eval $(thefuck -a)
fi

eval `dircolors ~/.dir_colors/dircolors`

source "$DOTFILES/commands.sh"

if [ -f ~/.cmus-vars ]; then
    source ~/.cmus-vars
fi

source "$DOTFILES/bash-it/completion/available/tmux.completion.bash"

alias SB='source ~/.bashrc'

appendToPath "$DOTFILES/scripts"

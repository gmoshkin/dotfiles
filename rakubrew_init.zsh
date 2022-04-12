rakubrew() {
    command rakubrew internal_hooked Zsh "$@" &&
    eval "`command rakubrew internal_shell_hook Zsh post_call_eval "$@"`"
}

compctl -K _rakubrew_completions -x 'p[2] w[1,register]' -/ -- rakubrew

_rakubrew_completions() {
    local WORDS POS RESULT
    read -cA WORDS
    read -cn POS
    reply=($(command rakubrew internal_shell_hook Zsh completions $POS $WORDS))
}

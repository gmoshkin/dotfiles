rakudobrew() {
    command rakudobrew internal_hooked "$@" &&
    eval "`command rakudobrew internal_shell_hook Zsh post_call_eval "$@"`"
}

compctl -K _rakudobrew_completions -x 'p[2] w[1,register]' -/ -- rakudobrew

_rakudobrew_completions() {
    local WORDS POS RESULT
    read -cA WORDS
    read -cn POS
    reply=($(command rakudobrew internal_shell_hook Zsh completions $POS $WORDS))
}

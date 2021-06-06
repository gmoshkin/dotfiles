rakudobrew() {
    command rakudobrew internal_hooked "$@" &&
    eval "`command rakudobrew internal_shell_hook Bash post_call_eval "$@"`"
}
_rakudobrew_completions() {
    COMPREPLY=($(command rakudobrew internal_shell_hook Bash completions $COMP_CWORD $COMP_LINE))
    $(command rakudobrew internal_shell_hook Bash completion_options $COMP_CWORD $COMP_LINE)
}
complete -F _rakudobrew_completions rakudobrew

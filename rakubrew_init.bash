rakubrew() {
    command rakubrew internal_hooked Bash "$@" &&
    eval "`command rakubrew internal_shell_hook Bash post_call_eval "$@"`"
}
_rakubrew_completions() {
    COMPREPLY=($(command rakubrew internal_shell_hook Bash completions $COMP_CWORD $COMP_LINE))
    $(command rakubrew internal_shell_hook Bash completion_options $COMP_CWORD $COMP_LINE)
}
complete -F _rakubrew_completions rakubrew

alias watch='watch --color -n 1'
alias cput='xsel --clipboard'
alias cget='cat | xsel --clipboard'

# check if `thefuck` is installed and make an alias for it
if type "thefuck" > /dev/null; then
    eval $(thefuck -a)
fi

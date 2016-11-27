alias watch='watch --color -n 1'

# check if `thefuck` is installed and make an alias for it
if type "thefuck" > /dev/null; then
    eval $(thefuck -a)
fi

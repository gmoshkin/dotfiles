set history save on
set history size unlimited
set logging enabled on
set print pretty on
set follow-fork-mode parent

source ~/dotfiles/gdbinit-gef.py

shell if [ ! -f ~/.gdbinit.local ]; then touch ~/.gdbinit.local; fi
source ~/.gdbinit.local

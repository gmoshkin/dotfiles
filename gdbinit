set history save on
set history size unlimited
set follow-fork-mode child

shell if [ ! -f ~/.gdbinit.local ]; then touch ~/.gdbinit.local; fi
source ~/.gdbinit.local

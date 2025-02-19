set history save on
set history size unlimited
set logging enabled on
set print pretty on
set follow-fork-mode parent

source ~/dotfiles/gdbinit-gef.py

handle SIGALRM ignore noprint
gef config context.layout "legend threads trace regs stack code args source memory extra"

shell if [ ! -f ~/.gdbinit.local ]; then touch ~/.gdbinit.local; fi
source ~/.gdbinit.local

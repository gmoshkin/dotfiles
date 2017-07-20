#!/bin/bash

USER=${USER:-$(whoami)}
REP_DIR=${REP_DIR:-"/space/${USER}/REP"}
CACHEFILE="/home/${USER}/.cache/ctrlp/%space%${USER}%REP.txt"

cd "$REP_DIR"
echo -n "generating tags... "

grep '\.[chCH]*[pPxX+]*$' "$CACHEFILE" |\
    grep -v 'cxx/test' |\
    grep -v 'kwclang/unit_test_data' |\
    grep -v 'sources/CSecurity' |\
    grep -v 'cglib/test' |\
    ctags -L -

echo "done"

#!/usr/bin/env sh


for f in /usr/lib/git-core/*; do [ -x $f ] && [ ! -d $f ] &&  bf=$(basename $f); cmd=${bf#git-}; echo "alias g${cmd}='git ${cmd}'"; done

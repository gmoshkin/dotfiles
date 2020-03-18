#!/usr/bin/env bash

for f in /usr/lib/git-core/*; {
    [ -x $f ] && [ ! -d $f ] && {
        bf=$(basename $f)
        cmd=${bf#git-}
        echo "alias g${cmd}='git ${cmd}'"
    }
}

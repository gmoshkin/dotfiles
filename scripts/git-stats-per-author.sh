#!/bin/env bash

git ls-files -z $1 |
    xargs -0n1 git blame -w |
    perl -n -e '/^\w*\s+\((.*?)\s+[\d]{4}/; print $1,"\n"' |
    sort -f |
    uniq -c |
    sort -n

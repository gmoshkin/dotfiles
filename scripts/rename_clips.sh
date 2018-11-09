#!/bin/bash

if [ "$#" -lt 1 ]; then
    echo 'No files to rename'
    exit 1
fi

FILEREGEX="Tom\s+Clancy's\s+Rainbow\s+Six\s+Siege\s+(\d\d).(\d\d).(\d\d\d\d)\s+-\s+(\d\d\.\d\d\.\d\d\.\d\d).DVR.mp4"
SUBSTITUTION='r6s-$3.$1.$2-$4-SOMETHING-UNTRIMMED.mp4'
rename "s/${FILEREGEX}/${SUBSTITUTION}/" "$@"

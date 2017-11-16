#!/bin/bash

while test $# -ge 2; do
    if [ $1 == file ]; then
        file=$2
    fi
    shift
    shift
done

filename=/tmp/cover.png
cp $filename /tmp/cover.old
echo yes | ffmpeg -i "$file" $filename
# if cmp $filename /tmp/cover.old; then
#     cp ~/Pictures/sad.png $filename
# fi

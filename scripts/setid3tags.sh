#!/usr/bin/env bash

YEAR_PATTERN='s/.*\([0-9][0-9][0-9][0-9]\).*\.mp3/\1/'
ARTIST_PATTERN='s/\([^-/]*\)-.*/\1/'
ALBUM_PATTERN='s/.*-\([^0-9]*\).*/\1/'
TRACK_NO_PATTERN='s/^[^0-9]*\([0-9]\+\).*\.mp3/\1/'
TITLE_PATTERN='s/[^0-9]*[0-9]*[.-]*\s*\(.\+\)\.mp3/\1/'

DIR="$1"
echo $DIR

TMP=$(mktemp)

echo -e 'filename\tyear\tartist\talbum\ttrack-no\ttitle' > $TMP
for f in "$DIR"/*.mp3; do
    echo -n "$f" >> $TMP
    mp3info -p '\t%y\t%a\t%l\t%n\t%t\n' "$f" >> $TMP
    echo -n "#" >> $TMP
    y=$(echo $f | sed "$YEAR_PATTERN")
    a=$(dirname "$f" | sed "$ARTIST_PATTERN")
    l=$(dirname "$f" | sed "$ALBUM_PATTERN")
    n=$(basename "$f" | sed "$TRACK_NO_PATTERN")
    t=$(basename "$f" | sed "$TITLE_PATTERN")
    echo -e "${f:--}\t${y:--}\t${a:--}\t${l:--}\t${n:--}\t${t:--}" >> $TMP
    echo "" >> $TMP
done

TMP2=$(mktemp)
cp $TMP $TMP2

vim $TMP

if cmp $TMP $TMP2 &> /dev/null ; then
    echo "Nothing to change"
    rm $TMP
    exit 0
fi

SCRIPT="$DIR"/script.sh
$DOTFILES/scripts/parse_script.awk $TMP > "$SCRIPT"
if bash "$SCRIPT" ; then
    rm "$SCRIPT"
else
    cp $TMP "$DIR/script"
fi

rm $TMP

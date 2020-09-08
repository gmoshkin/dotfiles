#!/usr/bin/bash

cat ~/data/all.json |
    jq '.functions[]|.name' -r |
    raku -e '
        $*IN.lines.race(:1batch, :8degree).map: {
            qqx[wetdt-klee-gen -i ~/data/all.json -f $_]
        }
    '
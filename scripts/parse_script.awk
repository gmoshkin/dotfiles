#!/usr/bin/awk -f
BEGIN {
    FS="\t"
}
NR <= 1 {
    next
}
NF < 1 {
    next
}
/^#/ {
    next
}
{
    printf("mp3info -y \"%d\" -a \"%s\" -l \"%s\" -n \"%s\" -t \"%s\" \"%s\"\n", $2, $3, $4, $5, $6, $1)
}

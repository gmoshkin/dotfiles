#!/usr/bin/env perl6

my @opts = qx[setxkbmap -query].lines
    .grep(*.starts-with('options:')).head.words.tail
    .split(',').grep(*.chars);

my $new-opts = ((@opts ∪ <ctrl:nocaps grp:win_space_toggle>) ∖ <grp:alt_shift_toggle>)
    .keys.join(',');

qx[setxkbmap -option];
qqx[setxkbmap -option $new-opts];

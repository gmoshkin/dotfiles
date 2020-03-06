#!/usr/bin/env perl6

loop {
    my $curr-win-x = qx[xdotool getactivewindow getwindowgeometry]
        .lines
        .grep(*.trim-leading.starts-with('Position'))
        .words
        .skip
        .head
        .split(',')
        .first;
    my $display-width = qx[xdotool getdisplaygeometry].words.first;

    my $curr-scene = ($curr-win-x < $display-width) ?? 'Scene' !! 'Scene 2';

    "$*HOME/.curr-scene".IO.spurt: $curr-scene;

    print "\e[2K$curr-scene\r";

    sleep 1;
}

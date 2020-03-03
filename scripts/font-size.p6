#!/usr/bin/env perl6

constant DCONF-FONT-KEY = '/org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9/font';

sub get-font-size {
    qqx[dconf read {DCONF-FONT-KEY}] ~~ / \d+ (\. \d+)? /;
    $/.Num
}

sub set-font-size($new-val) {
    qqx[dconf write {DCONF-FONT-KEY} $new-val];
}


multi sub MAIN {
    say get-font-size;
}

multi sub MAIN(Str:D $inc where *.starts-with('+' | '-')) {
    my $new-size = get-font-size() + try $inc.Num // $inc.substr(0, 1) ~ 1;
    set-font-size $new-size;
    say $new-size
}

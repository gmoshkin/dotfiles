#!/usr/bin/env perl6

constant DEFAULT-PROFILE = ':b1dcc9dd-5262-4d8d-a863-c897e6d979b9';
constant DCONF-FONT-KEY = "/org/gnome/terminal/legacy/profiles:/{DEFAULT-PROFILE}/font";

sub get-font {
    qqx[dconf read {DCONF-FONT-KEY}]
}

sub get-font-size {
    (get-font) ~~ / \d+ (\. \d+)? /;
    $/.Numeric
}

sub set-font-size($new-size) {
    my $new-font = get-font.subst(/ \d+ (\. \d+)?/, $new-size);
    run <dconf write>, DCONF-FONT-KEY, $new-font
}


multi sub MAIN {
    say get-font-size;
}

#| Must start with either + or -
multi sub MAIN(Str:D $offset where *.starts-with('+' | '-')) {
    my $new-size = (get-font-size) + try $offset.Numeric // $offset.substr(0, 1) ~ 1;
    set-font-size $new-size;
    say $new-size
}

multi sub MAIN(Numeric() $new-size) {
    set-font-size $new-size;
    say $new-size
}

#| Show default profile
multi sub MAIN('profile') {
    say DEFAULT-PROFILE
}

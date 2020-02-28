#!/usr/bin/env perl6

use Color::Scheme;

my $color = Color.new("#dc322f");

$color.^methods.say;

# my @palette = color-scheme($color, 'six-tone-ccw');
say color-scheme($color, $_)
    .map(*.rgb)
    .map(-> [$r, $g, $b] { "\e[48;2;{$r};{$g};{$b}m  \e[0m" })
    .join ~ " $_" for <
        split-complementary
        split-complementary-cw
        split-complementary-ccw
        triadic
        clash
        tetradic
        four-tone-cw
        four-tone-ccw
        five-tone-a
        five-tone-b
        five-tone-cs
        five-tone-ds
        five-tone-es
        analogous
        neutral
        six-tone-ccw
        six-tone-cw
    >;

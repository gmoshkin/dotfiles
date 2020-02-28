#!/usr/bin/env perl6

enum Outcome (
    YouLoose    => 0b000,
    First       => 0b001,
    Second      => 0b010,
    NoTie       => First +| Second,
    Tie         => 0b100,
    FirstOrTie  => 0b101,
    TieOrSecond => 0b110,
    Fork        => 0b111,
);

my @forks = (
    (First      , TieOrSecond),
    (NoTie      , FirstOrTie),
    (NoTie      , Tie),
    (NoTie      , TieOrSecond),
    (FirstOrTie , NoTie),
    (FirstOrTie , Second),
    (FirstOrTie , TieOrSecond),
    (Second     , FirstOrTie),
    (Tie        , NoTie),
    (TieOrSecond, First),
    (TieOrSecond, NoTie),
    (TieOrSecond, FirstOrTie),
);

sub is-fork(Outcome() $o1, Outcome() $o2) {
    Outcome($o1 +| $o2) == Fork
}

sub infix:<forks>(Outcome() $o1, Outcome() $o2) {
    is-fork($o1, $o2)
}

say @forks.map(&slip).map(&is-fork).all.so

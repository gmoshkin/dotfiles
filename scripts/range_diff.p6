#!/usr/bin/env perl6

sub diff(Range:D $lhs, Range:D $rhs) {
    (
        if min($lhs.min, $rhs.min) < max($lhs.min, $rhs.min) {
            min($lhs.min, $rhs.min)..max($lhs.min, $rhs.min)
        }
        else {
            Range
        }
    ),
    (
        if min($lhs.max, $rhs.max) < max($lhs.max, $rhs.max) {
            min($lhs.max, $rhs.max)..max($lhs.max, $rhs.max)
        }
        else {
            Range
        }
    )
}

say "{$_.gist} -> {gist diff |$_}" for [
    (0..4, 0..10),
    (0..10, 0..4),
    (0..10, 2..4),
    (2..10, 0..4),
    (3..5, 1..5),
    (1..5, 3..5),
    (1..5, 1..5),
    (1..5, 5..10),
    (7..9, 2..5),
    (0..3, 1..4),
];

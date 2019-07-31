#!/usr/bin/env perl6

constant rows = 2;
constant columns = 10;
my @red-row = |(0xff, 0x10, 0x10) xx columns;
my @blue-row = |(0x10, 0x10, 0xff) xx columns;
my @green-row = |(0x10, 0xff, 0x10) xx columns;
my @yellow-row = |(0xff, 0xff, 0x10) xx columns;
my @pixel-data = (^0x100).roll(3*columns*rows);

sub draw(*@pixel-data) {
    @pixel-data.batch(3).batch(columns).batch(2)
        .map(-> @_ { @_.elems > 1 ?? [Z] @_  !! @_ })
        .tree(*.join("\n"), *.map({
            if .elems > 2 {
                .map({"\x1b[38;2;{.join(";")};49m\c[upper half block]"}).join
            } else {
                "\x1b[38;2;{.head.join(";")}" ~
                (.elems > 1 ?? ";48;2;{.tail.join(";")}" !! '') ~
                "m\c[upper half block]";
            }
        }).join("\x1b[0m")).say;
}

draw(|@red-row, |@blue-row, |@green-row, |@yellow-row);
draw(|@red-row, |@blue-row, |@green-row);
say();
get();

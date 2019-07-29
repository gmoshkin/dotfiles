#!/usr/bin/env perl6

constant rows = 4;
constant columns = 30;
(^0x100).pick(3*rows*columns)
    .batch(3).batch(columns).batch(2).map({|zip(@^above, @^below)}).map(*.&zip)
    .tree(*.join("\n"), *.map(-> [@a, @b] {
        "\x1b[38;2;{@a.join(";")};48;2;{@b.join(";")}m\c[lower half block]";
    }).join()).say;
say();

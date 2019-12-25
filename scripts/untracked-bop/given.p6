#!/usr/bin/env perl6

given [1, 2] {
    when .elems == 2 {
        say "two";
    }
    when [*, *] {
        given $_ -> [$a, $b] {
            say "ok";
        }
    }
    default {
        say "nok";
    }
}

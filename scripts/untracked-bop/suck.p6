#!/usr/bin/env perl6

class A {
    method ass($i) {
        $i.uc;
    }
    method fuck {
        <a b c>.map(&ass);
    }
}

say A.fuck;

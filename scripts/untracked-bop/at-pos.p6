#!/usr/bin/env perl6

class A {
    has $.level = 0;
    multi method AT-POS($i) {
        say '  ' x $.level ~ $i;
        self.new(:level($.level+1));
    }
}

multi postcircumfix:<[ ]> (A $a, Str $s, :$ass = False) {
    say "$s $ass";
}

A.new[1..3;4,5;6];
A.new['fuck'];
A.new['ass']:ass;

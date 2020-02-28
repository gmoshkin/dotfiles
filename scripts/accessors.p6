#!/usr/bin/env perl6

class A { has $.a }

my $a = A.new(:a(10));
dd $a;

my &method-a = $a.can('a').first;
dd &method-a;

try method-a(); # doesn't work
dd $!;

dd method-a($a);


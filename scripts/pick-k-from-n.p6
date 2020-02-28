#!/usr/bin/env perl6

constant $N = 10;
constant $K = 4;
my @n-elems := (^100).roll($N).list;
my @k-elems := @n-elems.pick($K).list;
say @k-elems;

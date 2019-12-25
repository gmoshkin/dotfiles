#!/usr/bin/env perl6

sub infix:<ass> { |$^a , |$^b }
say 1 ass 2;
say [1] ass [2];
say [1] ass [2,3];
say [1,2] ass [3];
say [1,(2, 3)] ass [(4,5),6];
say (* ass *)([1,2],[3,4]);
say (1, 1, * ass * ... *).map(*.elems).head(10);

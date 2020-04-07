#!/usr/bin/env perl6

multi f(Str:D) { 's' }
multi f(Int:D) { 'i' }
multi f { samewith('as') }

say f 1;
say f 'a';
say f;

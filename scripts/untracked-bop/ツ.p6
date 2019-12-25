#!/usr/bin/env perl6

multi sub circumfix:<¯\_( )_/¯> ($_) { "circumfix: $_".say }
my \ツ = 'ツ';

¯\_(ツ)_/¯;


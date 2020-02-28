#!/usr/bin/env perl6

class Dog { has $.color }

my @dogs = (Dog.new(color => $_) for <Red White Blue Green>);

say @dogs».color;


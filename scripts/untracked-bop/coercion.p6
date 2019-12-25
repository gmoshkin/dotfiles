#!/usr/bin/env perl6

class Ass { has $.ass }

say Ass.new(ass => 'fuck');

multi Ass(Int:D $i) { Ass.new(:ass($i + 1)) }

say (&Ass)(1);
try say Ass(1);
.say with $!;

multi ass(Int:D $i) { Ass.new(:ass($i + 1)) }
say ass(1);
say 1.&ass;

class Fuck { has $.fuck; method Ass { Ass.new(ass => :$!fuck) } }

say Fuck.new(fuck => 'ass');
say Ass(Fuck.new(:fuck<ass>));

subset Shit of Int where * == any('shit'.ords);
try say Shit(1); .say with $!;
try say Shit('s'.ord); .say with $!;
say (1 ~~ Shit);
say ('s'.ord ~~ Shit);

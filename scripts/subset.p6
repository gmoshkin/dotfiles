#!/usr/bin/env perl6

{
    my subset Fuck where ($_ ~~ Int) && ($_ > 0);
    say 1 ~~ Fuck;
    say 0 ~~ Fuck;
    my Fuck $i = 1;
}
{
    my subset Fuck of Int where * > 0;
    say 1 ~~ Fuck;
    say 0 ~~ Fuck;
    my Fuck $i = 1;
    my Fuck $j = 1;
}
multi fib(0) { 1 }
multi fib(1) { 1 }
multi fib($n) { fib($n - 1) + fib($n - 2) }
say (^10).map: { fib($_) };
say (1, 1, * + * ... *).head(10);

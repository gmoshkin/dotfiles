#!/usr/bin/env perl6

use split-print;

split-print {
    $*l.say: 'fuck';    $*r.say: 'bitch';
    $*l.say: 'ass';     $*r.say: 'shit';
    $*l.say: 'shit';    $*r.say;
    $*l.say: 'piss';    $*r.say;
    $*l.say: 'aaaaaaa'; $*r.say: 'fuck';
}

split-print :1color, {
    $*l.say: 'red';
    say 'ass';
}

split-print :color<blue>, :border, {
    $*r.say: 'blue';
}

split-print :color("\e[32m"), {
    $*l.say: 'green';
}

split-print {
    $*l.say: '>>>';            $*r.say: '<<<';
    %*sp<l>.say: 'fuck';       %*sp<r>.say: 'shit';
    $*l.say: "\e[31mcolor\e[0m"; $*r.say: "doesn't work";
    $*l.say: '☹';              $*r.say;
    $*l.print: 'a';            $*r.print: "fuc\nk";
    $*l.print: 'b';            $*r.print: 'ity';
}

# say (my $i := IterationEnd) if-ended 'fuck';

# say zip-longest(<a b c>, <1 2>)

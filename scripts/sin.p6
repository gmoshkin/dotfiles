#!/usr/bin/env perl6

sub sine(:$scale = 50, :$step = .05, :$start = 0, :$head = 90, :$xscale = 1.5) {
    ($start, *+$step ... *)
        .head($head)
        .map(*.&[*]($xscale).cos.&[+](1).&[*]($scale/2).Int)
        .map({|(' ' xx ($_-1)), 'x', |(' ' xx ($scale-$_))})
        .&roundrobin
        .join("\n");
}

sine.say;

# react {
#     whenever Supply.interval(.5) -> $i {
#         sine:start($i/10).say;
#     }
# }

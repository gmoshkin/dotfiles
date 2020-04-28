#!/usr/bin/env perl6

sub hex(+c) { '#' ~ c».fmt('%02x').join }
say hex 12, 12, 23;

sub ass(+c) {
    given c.elems {
        when 1 { "5;{c}"           }
        when 3 { "2;{c.join(';')}" }
    }
}

say ass(90);
say ass(12, 12, 23);

sub ascii(:$fg, :$bg) {
    "\e["
        ~
    gather {
        take "38;{ass(|$fg)}" with $fg;
        take "48;{ass(|$bg)}" with $bg;
    }.join(';')
        ~
    "m"
}

say ascii(fg => 90) ~ "fuck\em";
say ascii(bg => [12, 12, 23], :fg(0, 0, 0));

sub clr { "\e[0m" }

sub show(+c) {
    (ascii(:fg(8), :bg(|c)), hex(|c), clr(),
     "\e[48;5;23m  ", clr(),
     ascii(:fg(8), :bg(|c)), hex(|c), clr()).join
}

say show(12, 12, 23);
say();

my %c = :80r, :80g, :80b;

loop {
    say show(|%c<r g b>);
    prompt.comb.Bag.map: -> (:$key, :$value) {
        %c{$key}    .= &{ $_ = min $_ + $value, 0xff } if $key ∈  <r g b>;
        %c{$key.lc} .= &{ $_ = max $_ - $value, 0x00 } if $key ∈  <R G B>;
    }
}

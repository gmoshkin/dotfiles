#!/usr/bin/env perl6

use split-print;

constant RST = "\e[0m";
constant RED = "\e[31m"; sub RED($s) { RED ~ $s ~ RST }
constant GRN = "\e[32m"; sub GRN($s) { GRN ~ $s ~ RST }
constant YLW = "\e[33m"; sub YLW($s) { YLW ~ $s ~ RST }
constant BLU = "\e[34m"; sub BLU($s) { BLU ~ $s ~ RST }
constant MGT = "\e[35m"; sub MGT($s) { MGT ~ $s ~ RST }
constant CYN = "\e[36m"; sub CYN($s) { CYN ~ $s ~ RST }

class MyRange {
    has $.min   is rw;
    has $.elems is rw;

    method new(:$min, :$max, :$elems) {
        if $max.defined {
            self.bless(:$min, :elems($max - $min))
        }
        elsif $elems.defined {
            self.bless(:$min, :$elems)
        }
        else {
            die "need one of \$max or \$elems"
        }
    }

    method move-min($ofs) { self.min += $ofs; self.elems -= $ofs }

    method max { self.min + self.elems }
    method Str { "$.min..^$.max" }
    method gist { self.Str }
    method list { self.min..^self.max }
    method Range { self.min ..^ self.max }
}
multi sub range($min, $elems) { MyRange.new: :$min, :$elems }
multi sub range(Range:D $r)   { MyRange.new: min => $r.min, elems => $r.elems }

sub infix:<til> ($min, $max)   { MyRange.new: :$min, elems => $max - $min }
sub infix:<..+> ($min, $elems) { MyRange.new: :$min, :$elems }

class Fragment {
    has MyRange $.range;
    has $.id;

    method new(:$range, :$id) {
        self.bless:
            range => MyRange.new(min => $range.min, elems => $range.elems),
            :$id
    }
    method Str {
        if $.id.defined {
            "f\{\e[7;3{$.id}m$.range\e[0m\}"
        }
        else {
            "f\{$.range\}"
        }
        # 'f{' ~ $.range ~ ($.id.defined ?? " $.id" !! '') ~ '}'
    }
}

sub frag($range, $id?) { Fragment.new(:$range, :$id) }

class Paragraph {
    has Str      $.text;
    has Fragment @.frags;

    method new(:$text, :@frags) {
        if not valid-frags(@frags».range, $text.chars) {
            die "'{@frags}' are not valid fragments"
        }
        self.bless(:$text, :@frags)
    }

    method Str {
        ($.text.comb.rotor(@.frags».range».elems) Z @.frags».id).map(-> [$txt, $id] {
            $txt.join.fmt($id.defined ?? "\e[7;3{$id}m%s\e[0m" !! "%s")
        }).join
    }
    method gist { '"' ~ self.Str ~ '"' }
}
multi sub par($text, @frags where .all ~~ Fragment) { Paragraph.new(:$text, :@frags) }
multi sub par($text) { callwith($text, 0 til $text.chars) }
multi sub par($text, *@frags) {
    Paragraph.new: :$text, frags => @frags.map: {
        state $last-range = 0 til 0;
        # my $id;
        # if $_ ~~ Pair {
        #     $id = .value;
        #     $_ = .key;
        # }
        # $last-range = do given $_ {
        #     when MyRange {
        #         $_
        #     }
        #     when Int {
        #         $last-range ..+ $_
        #     }
        #     default {
        #         die
        #     }
        # }
        # Fragment.new(range => $last-range, :$id)
        when MyRange {
            $last-range = $_;
            Fragment.new(range => $_)
        }
        when Pair {
            $last-range = do given .key {
                when MyRange {
                    $_
                }
                when Int {
                    $last-range.max ..+ $_
                }
            }
            Fragment.new(range => $last-range, id => .value)
        }
        when Int {
            $last-range = $last-range.max ..+ $_;
            Fragment.new(range => $last-range)
        }
    }
}

say par('abcd');
say par('abcd', 0 til 4);
say par('abcd', 0 til 2 => 1, 2 til 4);
say par('abcd', 2, 2 => 1);
say par('abZcd', 1, 3 => 1, 1);
say par('aXbcXd', 1, 4 => 1, 1);

sub max($_ is raw) {
    .excludes-max ?? .max - 1 !! .max
}

sub valid-frags(@frags, $chars --> Bool:D) {
    return False unless @frags.head.min == 0;
    return False unless @frags.tail.max == $chars;
    @frags.rotor(2 => -1).map(-> [$l, $r] {
        $r.min == $l.max
    }).all.so
}

dd frag(1..4);
dd frag(1..4, 1);
dd my @frags = <0 3 7 10>.rotor(2 => -1).flat.map: { frag($^l ..^ $^r) }
dd valid-frags @frags».range, 10;
@frags[1] = frag(3..8);
dd valid-frags @frags».range, 10;
@frags[1] = frag(3..6);
dd valid-frags @frags».range, 10;
dd valid-frags [0..3, 4..10], 11;

class DataClump {
    has $.name;
    has $.it;
    has $.text;
    has $.op-it is rw;
    has $.frag  is rw = self.it.pull-one;
    has $.sp    is rw = self.frag.range;
    has $.len   is rw = 0;
    has $.ended is rw = False;
    has @.res         = [];
    has $.op    is rw = self.op-it.&maybe-pull-one;

    method new($name, @frags, $text, @ops) {
        self.bless(:$name, it => @frags.iterator, :$text, op-it => @ops.iterator)
    }

    method id {
        self.frag.id
    }

    method new-sp {
        range(self.sp.min, self.len)
    }

    method substr($sp?) {
        '"' ~ self.text.substr(($sp // self.sp).Range) ~ '"'
    }

    method new-substr {
        self.substr(self.new-sp)
    }

    method advance {
        if self.len == self.sp.elems {
            if (my $next := self.it.pull-one) !=:= IterationEnd {
                self.frag = $next;
                self.sp = self.frag.range;
                %*sp{$.name}.say: "next frag"
            }
            else {
                self.ended = True;
                %*sp{$.name}.say: "end"
            }
        }
        else {
            self.sp.move-min(self.len);
            %*sp{$.name}.say: "cut range"
        }
        self.len = 0

    }
}

sub maybe-pull-one($iterator) {
    $iterator.pull-one.&{
        $_ =:= IterationEnd ?? Nil !! $_
    }
}

sub diff-paragraphs(Paragraph:D $lhs, Paragraph:D $rhs, :@text-ops) {
    say '━' x qx[tput cols];
    say BLU ~ &?ROUTINE.name ~ RST ~ ($lhs, $rhs, |@text-ops)».gist.join(', ').fmt('(%s)');

    my (:add(@add-ops), :remove(@rem-ops)) := @text-ops.classify(*.key, as => *.value);

    my DataClump $l .= new('l', $lhs.frags, $lhs.text, @rem-ops);
    my DataClump $r .= new('r', $rhs.frags, $rhs.text, @add-ops);


    my $add-it = @add-ops.iterator;
    my $curr-add = $add-it.&maybe-pull-one;

    my $rem-it = @rem-ops.iterator;
    my $curr-rem = $rem-it.&maybe-pull-one;

    ROOT: while $l.ended.not and $r.ended.not {

        say '─' x qx[tput cols];
        split-print {
            for $l, $r {
                %*sp{.name}.say: "frag: {.frag}, {.substr}, ended: {.ended}";
                if .sp.min > .sp.max {%*sp{.name}.say: " fuck"; last ROOT }
            }
        }

        while $l.len < $l.sp.elems and $r.len < $r.sp.elems {
            split-print :color<cyan>, {
                for $l, $r {
                    ++.len;
                    %*sp{.name}.print: "advanced +1";
                    while .op ∩ .new-sp {
                        %*sp{.name}.print: " +{.op.elems}";
                        .len += .op.elems;
                        .op = .op-it.&maybe-pull-one;
                    }
                    while .op ∩ .sp {
                        %*sp{.name}.print: " ++{.op.elems}";
                        .len += .op.elems;
                        .op = .op-it.&maybe-pull-one;
                    }
                    %*sp{.name}.say: " -> {.new-substr}";
                }
            }
        }

        if $l.id !eqv $r.id {
            split-print :color<green>, {
                for $l, $r {
                    %*sp{.name}.say: "add {.new-substr}"; .res.push(.new-sp);
                }
            }
        }
        else {
            split-print :color<red>, {
                for $l, $r {
                    %*sp{.name}.say: "skip {.new-substr}";
                }
            }
        }

        split-print :color<yellow>, {
            .advance for $l, $r
        }
    }

    die unless $l.ended and $r.ended;

    say '━' x qx[tput cols];
    $l.res, $r.res
}

my &check = {
    say '>>>>> ', ($*wanted eqv $*got ?? GRN !! RED), $*wanted => $*got, RST;
    say();
    die unless $*wanted eqv $*got
}

{
    my ($*wanted, $*got) = diff-paragraphs(
        par('abcd'),
        par('abcd', 0 til 2, 2 til 4 => 1),
    ), (
        [2 til 4,],
        [2 til 4,],
    );
    check
}

{
    my ($*wanted, $*got) = diff-paragraphs(
        par('abcd'),
        par('abcd', 0 til 1, 1 til 3 => 1, 3 til 4),
    ), (
        [1 til 3,],
        [1 til 3,],
    );
    check
}

{
    my ($*wanted, $*got) = diff-paragraphs(
        par('abcd'),
        par('abcd', 0 til 1 => 1, 1 til 3, 3 til 4 => 1),
    ), (
        [0 til 1, 3 til 4],
        [0 til 1, 3 til 4],
    );
    check
}

{
    my ($*wanted, $*got) = diff-paragraphs(
        par('abcd', 0 til 3 => 1, 3 til 4),
        par('abcd', 0 til 1, 1 til 4 => 1),
    ), (
        [0 til 1, 3 til 4],
        [0 til 1, 3 til 4],
    );
    check
}

{
    my ($*wanted, $*got) = diff-paragraphs(
        par('abcd'),
        par('aabcd', 0 til 3, 3 til 5 => 1),
        text-ops => [ add => 1 ..+ 1 ]
    ), (
        [2 til 4],
        [3 til 5],
    );
    check
}

{
    my ($*wanted, $*got) = diff-paragraphs(
        par('aabcd', 0 til 3, 3 til 5 => 1),
        par('abcd'),
        text-ops => [ remove => 1 ..+ 1 ]
    ), (
        [3 til 5],
        [2 til 4],
    );
    check
}

{
    my ($*wanted, $*got) = diff-paragraphs(
        par('abcd', 0 til 2, 2 til 4 => 1),
        par('aabcd'),
        text-ops => [ add => 1 ..+ 1 ]
    ), (
        [2 til 4],
        [3 til 5],
    );
    check
}

{
    my ($*wanted, $*got) = diff-paragraphs(
        par('abZcd',  1, 3 => 1, 1),
        par('aXbcXd', 1, 4 => 1, 1),
        text-ops => [ add => 1 til 2, remove => 2 til 3, add => 4 til 5  ]
    ), (
        [],
        [],
    );
    check
}

{
    my ($*wanted, $*got) = diff-paragraphs(
        par('abZcd',  1, 3 => 1, 1),
        par('aXbcXd', 1, 5 => 1),
        text-ops => [ add => 1 til 2, remove => 2 til 3, add => 4 til 5  ]
    ), (
        [4 til 5],
        [5 til 6],
    );
    check
}

{
    my ($*wanted, $*got) = diff-paragraphs(
        par('aXbcXd', 1, 5 => 1),
        par('abZcd',  1, 3 => 1, 1),
        text-ops => [ remove => 1 til 2, add => 2 til 3, remove => 4 til 5  ]
    ), (
        [5 til 6],
        [4 til 5],
    );
    check
}

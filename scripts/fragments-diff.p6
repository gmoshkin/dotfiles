#!/usr/bin/env perl6

use split-print;

constant RST = "\e[0m";
constant R = 1; constant RED = "\e[3{R}m"; sub RED($s) { RED ~ $s ~ RST }
constant G = 2; constant GRN = "\e[3{G}m"; sub GRN($s) { GRN ~ $s ~ RST }
constant Y = 3; constant YLW = "\e[3{Y}m"; sub YLW($s) { YLW ~ $s ~ RST }
constant B = 4; constant BLU = "\e[3{B}m"; sub BLU($s) { BLU ~ $s ~ RST }
constant M = 5; constant MGT = "\e[3{M}m"; sub MGT($s) { MGT ~ $s ~ RST }
constant C = 6; constant CYN = "\e[3{C}m"; sub CYN($s) { CYN ~ $s ~ RST }

# my $*DEBUG = False;

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

if $*DEBUG {
    say par('abcd');
    say par('abcd', 0 til 4);
    say par('abcd', 0 til 2 => 1, 2 til 4);
    say par('abcd', 2, 2 => 1);
    say par('abZcd', 1, 3 => 1, 1);
    say par('aXbcXd', 1, 4 => 1, 1);
}

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

    method next-op {
        self.len += self.op.elems;
        self.op = self.op-it.&maybe-pull-one;
    }

    method advance {
        if self.len == self.sp.elems {
            if (my $next := self.it.pull-one) !=:= IterationEnd {
                self.frag = $next;
                self.sp = self.frag.range;
                %*sp{$.name}.say: "next frag" if $*DEBUG
            }
            else {
                self.ended = True;
                %*sp{$.name}.say: "end" if $*DEBUG
            }
        }
        else {
            self.sp.move-min(self.len);
            %*sp{$.name}.say: "cut range" if $*DEBUG
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
    say '━' x qx[tput cols] if $*DEBUG;
    say BLU ~ &?ROUTINE.name ~ RST ~ ($lhs, $rhs, |@text-ops)».gist.join(', ').fmt('(%s)');

    my (:add(@add-ops), :remove(@rem-ops)) := @text-ops.classify(*.key, as => *.value);

    my DataClump $l .= new('l', $lhs.frags, $lhs.text, @rem-ops);
    my DataClump $r .= new('r', $rhs.frags, $rhs.text, @add-ops);


    my $add-it = @add-ops.iterator;
    my $curr-add = $add-it.&maybe-pull-one;

    my $rem-it = @rem-ops.iterator;
    my $curr-rem = $rem-it.&maybe-pull-one;

    FRAG: while $l.ended.not and $r.ended.not {

        # say '─' x qx[tput cols];
        split-print :border<before>, {
            for $l, $r {
                %*sp{.name}.say: "frag: {.frag}, {.substr}, ended: {.ended}" if $*DEBUG;
                if .sp.min > .sp.max {%*sp{.name}.say: " fuck" if $*DEBUG; last FRAG }
            }
        }

        while $l.len < $l.sp.elems and $r.len < $r.sp.elems {
            split-print :color<cyan>, {
                SIDE: for $l, $r {
                    %*sp{.name}.say: "op: {.op // ''}, sp: {.sp}" if $*DEBUG;
                    if .op eqv .sp {
                        .next-op;
                        .advance;
                        %*sp{.name}.say: "frag: {.frag}, {.substr}, ended: {.ended}" if $*DEBUG;
                        redo SIDE
                    }
                    else {
                        %*sp{.name}.say if $*DEBUG;
                    }
                    ++.len;
                    %*sp{.name}.print: "advanced +1" if $*DEBUG;
                    if .op ∩ .new-sp {
                        %*sp{.name}.print: " +{.op.elems}" if $*DEBUG;
                        .next-op;
                    }
                    if .op ∩ .sp {
                        %*sp{.name}.print: " ++{.op.elems}" if $*DEBUG;
                        .next-op;
                    }
                    %*sp{.name}.say: " -> {.new-substr}" if $*DEBUG;
                }
            }
        }

        if $l.id !eqv $r.id {
            split-print :color<green>, {
                for $l, $r {
                    if .new-sp.min == .res.tail.max {
                        %*sp{.name}.say: "join last +{.new-substr}" if $*DEBUG;
                        .res.tail.elems += .len;
                    }
                    else {
                        %*sp{.name}.say: "add {.new-substr}" if $*DEBUG;
                        .res.push(.new-sp);
                    }
                }
            }
        }
        else {
            split-print :color<red>, {
                for $l, $r {
                    %*sp{.name}.say: "skip {.new-substr}" if $*DEBUG;
                }
            }
        }

        split-print :color<yellow>, :border<after>, {
            .advance for $l, $r
        }
    }

    die RED("{.name} didn't end") unless .ended for $l, $r;

    say '━' x qx[tput cols] if $*DEBUG;
    $l.res, $r.res
}

my &check = {
    say '>>>>> ', ($*wanted eqv $*got ?? GRN !! RED),
        $*wanted.&{ .[0] => .[1] }, ' X ', $*got.&{ .[0] => .[1] }, RST;
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

{
    my ($*wanted, $*got) = diff-paragraphs(
        par('abXcd', 2, 1 => 4, 2),
        par('abcd'),
        text-ops => [ remove => 2 ..+ 1 ]
    ), (
        [],
        [],
    );
    check
}

{
    my ($*wanted, $*got) = diff-paragraphs(
        par('aXbXcXd', 1, 1 => R, 1, 1 => G, 1, 1 => B, 1),
        par('abcd'),
        text-ops => [ remove => 1..+1, remove => 3..+1, remove => 5..+1 ]
    ), (
        [],
        [],
    );
    check
}

{
    my ($*wanted, $*got) = diff-paragraphs(
        par('abXcd', 2, 1 => 4, 2),
        par('aZbcZd', 1, 1 => 2, 2, 1 => 5, 1),
        text-ops => [ add => 1..+1, remove => 2..+1, add => 4..+1 ]
    ), (
        [],
        [],
    );
    check
}

{
    my ($*wanted, $*got) = diff-paragraphs(
        par('abc', 2 => B, 1),
        par('abc', 1, 2 => G),
    ), (
        [0..+3],
        [0..+3],
    );
    check
}

{
    my ($*wanted, $*got) = diff-paragraphs(
        par('aXbc', 3 => B, 1),
        par('abXc', 1, 3 => G),
        text-ops => [ :remove(1..+1), :add(2..+1) ]
    ), (
        [0..+4],
        [0..+4],
    );
    check
}

{
    my $*DEBUG = True;
    my ($*wanted, $*got) = diff-paragraphs(
        par('abXcd', 2 => B, 1 => R, 1 => B, 1),
        par('aZbcZd', 4 => G, 2 => M),
        text-ops => [ add => 1..+1, remove => 2..+1, add => 4..+1 ]
    ), (
        [],
        [],
    );
    check
}

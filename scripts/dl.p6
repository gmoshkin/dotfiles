#!/usr/bin/env perl6

class DistOp is Cool {
    has $.kind where '+'|'-'|'~'|'.';
    has $.dist;

    method Numeric { self.dist }
    method Real    { self.dist }
    method Str     {
        { '-' => "\e[31m", '+' => "\e[32m", '~' => "\e[33m", '.' => "\e[34m" }{self.kind}
            ~ "{self.kind}({self.dist})\e[0m"
    }

    method new($kind, $dist) { self.bless(:$kind, :$dist) }

    method add            { DistOp.new('+', self.dist + 1) }
    method remove         { DistOp.new('-', self.dist + 1) }
    method replace($dist) { DistOp.new($dist ?? '~' !! '.', self.dist + $dist) }
}

multi sub infix:<cmp>(DistOp:D \l, DistOp:D \r) { l.Real cmp r.Real }

sub dlm($lhs, $rhs) {
    my @l = *, |($lhs ~~ Stringy ?? $lhs.comb !! $lhs);
    my @r = *, |($rhs ~~ Stringy ?? $rhs.comb !! $rhs);
    my @dlm;
    @dlm[ 0][ 0] = DistOp.new('.', 0);
    @dlm[$_][ 0] = DistOp.new('-', $_) for 1..^@l.elems;
    @dlm[ 0][$_] = DistOp.new('+', $_) for 1..^@r.elems;

    my int $l_elems = @l.elems;
    my int $r_elems = @r.elems;
    loop (my int $l-i = 1; $l-i < $l_elems; ++$l-i) {
        loop (my int $r-i = 1; $r-i < $r_elems; ++$r-i) {
            my $l = @l[$l-i];
            my $r = @r[$r-i];
            @dlm[$l-i][$r-i] = min @dlm[$l-i - 1][$r-i    ].remove,
                                   @dlm[$l-i    ][$r-i - 1].add,
                                   @dlm[$l-i - 1][$r-i - 1].replace(dist($l, $r)),
                                   :by(*.dist);
        }
    }

    @dlm;
}

sub dist($lhs, $rhs) {
    if $lhs & $rhs ~~ Stringy & { .chars <= 1 } {
        return +($lhs ne $rhs)
    }

    dlm($lhs, $rhs).&{
        .tail.tail / max .elems, .tail.elems
    }
}

sub infix:<..+>($min, $elems) { $min..^($min + $elems) }
say (1..+1).&{ $_, .excludes-max, $_.min, $_.max };

sub infix:<join>(Range:D \l, Range:D \r) { r.excludes-max ?? l.min..^r.max !! l.min..r.max}
say [(1..^2), (2..^3)].&{ .[0], .[1], .[0] join .[1] };
my %h = a => 1..2, b => 2..3;
say %h;
%h<b> join= 3..4;
say %h;

class RangeOp is Cool {
    has $.kind where '+'|'-'|'~'|'.';
    has $.l is rw;
    has $.r is rw;

    method Str {
        given self.kind {
            when '-' { "\e[31m{self.kind}[{self.l.gist}]\e[0m" }
            when '+' { "\e[32m{self.kind}[{self.r.gist}]\e[0m" }
            when '~' { "\e[33m{self.kind}[{self.l.gist} -> {self.r.gist}]\e[0m" }
            when '.' { "\e[34m{self.kind}[{self.l.gist} = {self.r.gist}]\e[0m" }
        }
    }
}

sub ops($lhs, $rhs, @dlm = dlm($lhs, $rhs)) {
    my @lhs = $lhs ~~ Stringy ?? $lhs.comb !! |$lhs;
    my @rhs = $rhs ~~ Stringy ?? $rhs.comb !! |$rhs;

    my int $l-i = @lhs.elems;
    my int $r-i = @rhs.elems;

    my @ops;

    repeat {
        my (:$kind, :$dist) := @dlm[$l-i][$r-i];
        my ($l, $r) = do given $kind {
            when '+' {        Nil  , --$r-i ..+ 1 }
            when '-' { --$l-i ..+ 1,        Nil   }
            when '~' { --$l-i ..+ 1, --$r-i ..+ 1 }
            when '.' { --$l-i ..+ 1, --$r-i ..+ 1 }
        }
        if @ops.tail.kind eqv $kind {
            @ops.tail.l .= &{ $l join $_ } with $l;
            @ops.tail.r .= &{ $r join $_ } with $r;
        }
        else {
            @ops.push(RangeOp.new(:$kind, :$l, :$r))
        }
    } until $l-i & $r-i == 0;

    @ops.reverse
}

sub get-diff-side(@ops, Str :$lhs, Str :$rhs where {$lhs.defined ^ $rhs.defined}) {
    gather for @ops -> (:$kind, :$l, :$r) {
        my $color = do given $kind {
            when '-' { $lhs ?? "\e[31m" !! next }
            when '+' { $rhs ?? "\e[32m" !! next }
            when '~' { "\e[33m" }
            when '.' { "" }
        }
        take "{$color}{$lhs.substr($l)}\e[0m" with $lhs;
        take "{$color}{$rhs.substr($r)}\e[0m" with $rhs;
    }.join
}

multi sub show-diff(Str:D $lhs, Str:D $rhs, @ops = ops($lhs, $rhs)) {
    say "\"&get-diff-side(:$lhs, @ops)\" V \"&get-diff-side(:$rhs, @ops)\"";
}

multi sub show-diff(@lhs, @rhs, @ops = ops(@lhs, @rhs)) {
    say "<" x 7;
    LEFT: for @ops -> (:$kind, :$l, :$r) {
        my $color = do given $kind {
            when '-' { "\e[31m" }
            when '+' { next LEFT }
            default  { "" }
        }
        if $kind eq '~' {
            for @lhs[@$l] Z @rhs[@$r] -> ($lhs, $rhs) {
                say get-diff-side(:$lhs, ops($lhs, $rhs));
            }
        }
        else {
            say $color, $_, "\e[0m" for @lhs[@$l];
        }
    }
    say "=" x 7;
    RIGHT: for @ops -> (:$kind, :$l, :$r) {
        my $color = do given $kind {
            when '-' { next RIGHT }
            when '+' { "\e[32m" }
            default  { "" }
        }
        if $kind eq '~' {
            for @lhs[@$l] Z @rhs[@$r] -> ($lhs, $rhs) {
                say get-diff-side(:$rhs, ops($lhs, $rhs));
            }
        }
        else {
            say $color, $_, "\e[0m" for @rhs[@$r];
        }
    }
    say ">" x 7;
}

sub print-matr(@m) {
    my &fmt-row = { .map(*.fmt("% 16s")).join }
    @m.&{
        # .head.say;
        .head.&fmt-row.fmt(                       "⎡%s⎤" ).say;
        .skip(1).head(*-1).map: { $_.&fmt-row.fmt("⎢%s⎥").say };
        .tail.&fmt-row.fmt(                       "⎣%s⎦").say;
    }
}
print-matr dlm(<fuck ass shit>, <fuck pass shit>);
print-matr dlm(<fuck>, <duck>);
say dist(<fuck>, <duck>);
say min :by(*.dist), DistOp.new('-', 1), DistOp.new('~', .5), DistOp.new('+', 2);
say DistOp.new('-', 1)  cmp DistOp.new('~', .5);
say DistOp.new('~', .5) cmp DistOp.new('-', 1);
say DistOp.new('-', .5) cmp DistOp.new('~', .5);

for [(<fuck>, <duck>), (<shit>, <piss>), (<fuck>, <ass>), ('', 'wow')] -> [$l, $r] {
    show-diff($l, $r);
    say ops($l, $r)».Str;
    print-matr dlm($l, $r);
}

for [(<fuck ass shit>, <fuck cunt piss>), (<fuck ass fuck>, <fuck ass ass fuck>)] -> [$l, $r] {
    say "[$l] V [$r]";
    show-diff($l, $r);
    say ops($l, $r)».Str;
    print-matr dlm($l, $r);
}

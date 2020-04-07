class Buffer {
    has $.buffer is rw;
    method print(*@args)  { self.buffer ~= @args.join.subst(/ "\e[" <-[m]>* m /, :g) }
    method say(*@args)    { self.print: @args, "\n" }
    method lines          { self.buffer.?lines // () }
    method Bool(--> Bool) { self.buffer.Bool }
}

multi sub start-color(Str:D $color) {
    if $color ~~ / "\e[" <-[m]>* m / {
        print $color;
    }
    else {
        constant %color-codes = red => 1, green => 2, yellow => 3, blue => 4, magenta => 5, cyan => 6;
        with (my $code = %color-codes{$color}) {
            samewith($code)
        }
    }
}
multi sub start-color(Int:D $i) {
    print "\e[{$i < 10 ?? 30 + $i !! $i}m"
}
sub end-color {
    print "\e[0m"
}

sub split-print(&cb, :$cols = qx[tput cols].Int, :$color, :$border = False) is export {
    my Buffer $*l .= new;
    my Buffer $*r .= new;
    my %*sp = l => $*l, r => $*r;
    cb();
    return unless $*l or $*r;
    my $l-cols = $cols div 2;
    my $r-cols = $cols - $l-cols - 1;
    start-color $color if $color;
    say '─' x $l-cols ~ '┬' ~ '─' x $r-cols if $border;
    sub print-line($l, $r) {
        # TODO: wow fuck you'll have to iteate over the printable counts, add
        # the correct padding and also turn off the attrbitues at the end and
        # restore them at the start of lines, that's a shit ton of work!
        #
        # easier would be to implement attributed strings
        for zip-longest($l.comb.rotor($l-cols, :partial)».join,
                        $r.comb.rotor($r-cols, :partial)».join,
                        default => '') -> ($l, $r) {
            # my $l-printable-count = $l.subst(/ "\e[" <-[m]>* m /, :g).chars;
            # my $r-printable-count = $r.subst(/ "\e[" <-[m]>* m /, :g).chars;
            printf "%-{$l-cols}s│%s\n", $l, $r
        }
    }
    for zip-longest($*l.lines, $*r.lines, default => '') -> ($l, $r) {
        print-line $l, $r
    }
    say '─' x $l-cols ~ '┴' ~ '─' x $r-cols if $border;
    end-color if $color;
}

sub infix:<if-ended> (Mu \i, $default) is export {
    i =:= IterationEnd ?? $default !! i
}

sub zip-longest(@l, @r, :$default) is export {
    my ($l-it, $r-it) = (@l.iterator, @r.iterator);
    my @res;
    gather loop {
        my $l := $l-it.pull-one;
        my $r := $r-it.pull-one;
        last if $l =:= IterationEnd and $r =:= IterationEnd;
        take ($l if-ended $default, $r if-ended $default);
    }
}

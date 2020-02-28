#!/usr/bin/env perl6

my @base-types = <int unsigned double float char short void>;
my @with-pointers = @base-types.map: * ~ ' *';
my @all-types = |@base-types, |(['const ', ''] X~ @with-pointers);

sub MAIN (Int:D :$max-types = 100, Int:D :$n-calls = 100) {
    # $max-types.perl.note;
    # $n-calls.perl.note;
    for 1..$n-calls {
        my @cur-types = @all-types.roll((1..$max-types).pick);
        my $to-find = @cur-types.pick;
        my $n = (^@cur-types.grep($to-find).elems).pick;
        # :$n.perl.note;
        # :$to-find.perl.note;
        # :@cur-types.perl.note;
        say("find_nth_type<{[$n, $to-find, |@cur-types].join: ', '}>(),");
    }
}

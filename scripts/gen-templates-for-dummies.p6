#!/usr/bin/env perl6

constant @base-types = ['int', 'unsigned', 'double', 'float', 'char', 'short', 'void'];
constant @with-pointers = @base-types.map(-> $t { $t ~ ' *' });
constant @with-pointers-and-const = @with-pointers.map(-> $t { Slip('const ' ~ $t, $t) });
constant @all-types = [Slip(@base-types), Slip(@with-pointers-and-const)];

for 1..5 -> $_ {
    my $n-types-to-generate = (1..10).pick();
    my @cur-types = @all-types.roll($n-types-to-generate);
    my $to-find = @cur-types.pick();
    my @types-matching-to-find = grep(-> $t { $t eqv $to-find }, @cur-types);
    my $n-to-find-in-cur-types = @types-matching-to-find.elems();
    my $n = (0..$n-to-find-in-cur-types-1).pick();
    print('find_nth_type<', $n, ', ', $to-find, ', ', @cur-types.join(', '), ">(),\n");
}

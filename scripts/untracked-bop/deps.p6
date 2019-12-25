#!/usr/bin/env perl6

sub get-deps(@t, %d --> List) {
    # say "@t: {@t.gist}, %d: {%d.gist}";
    if @t.not and %d.not {
        return []
    }
    my $roots = @t.Set ∖ %d.values>>.List.Set;
    my @new_t = @t.grep({$_ ∉ $roots});
    my %new_d = %d.kv.grep(-> Int() $k, $v {$k ∉ $roots}).flat;
    # say "new_t: {@new_t}, new_d: {%new_d.Str}";
    # :$roots, :@new_t, :%new_d
    |$roots.keys, |get-deps(@new_t, %new_d)
}

get-deps(1..8, {1=>[2,3], 2=>[3,5], 3=>[4,7], 4=>[5]}).say

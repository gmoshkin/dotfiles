#!/usr/bin/env perl6

sub ass(:%ass (Str:D :$ass, :@fuck (Str:D $str, Int:D $int))) {
    printf '{"ass": "%s", "fuck": ["%s", %d]}', $ass, $str, $int;
    put();
}

ass(:ass{:fuck(['ass', 42]), :ass<fuck>});

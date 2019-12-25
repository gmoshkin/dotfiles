#!/usr/bin/env perl6

multi quick-sort([]) { [] }
multi quick-sort(Any:U) { |() }

multi quick-sort([$pivot, *@data]) {
    flat(
        quick-sort(.{Less}),
        $pivot,
        quick-sort(.{More})
    ) given @data.classify(* <=> $pivot);
}

given (^10).pick(*) {
    .say;
    .&quick-sort.say;
}

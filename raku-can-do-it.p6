#!/usr/bin/env perl6

class A { method action(|c) { say c; self } }

{
    A.new.&{
        .action(:fuck)
        .action(:ass);
        if ($*PERL.version > v6.c) {
            .action(:new)
        }
        else {
            .action(:old)
        }
        .action(:bitch)
    }
}

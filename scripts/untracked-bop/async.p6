#!/usr/bin/env perl6

start { sleep 1.5; say $*THREAD, ": hi"; }
await Supply.from-list(<A B C D E F>).throttle: 2, {
    sleep 0.5;
    say $*THREAD, ": $_"
}

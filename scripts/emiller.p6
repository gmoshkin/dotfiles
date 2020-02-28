#!/usr/bin/env perl6

use v6.d.PREVIEW;

my $channel = Channel.new;

constant $N = 1000;

my @ten_tasks = (^$N).map: {
    start {
        my $thread = $*THREAD.id;
        await $channel;
        say "HOLY MOLEY SOMEONE STOLE MY THREAD" if $thread != $*THREAD.id;
    }
}

$channel.send("Ring ring") for ^$N;
$channel.close;

await @ten_tasks;

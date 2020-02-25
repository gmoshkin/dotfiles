#!/usr/bin/env perl6

(^(qx[tput cols] / 2 * (qx[tput lines] - 1)))
    .map({"\e[48;2;{(^0x100).pick(3).join(';')}m  \e[0m"})
    .rotor(qx[tput cols] / 2)
    .map(*.join)
    .join("\n")
    .say

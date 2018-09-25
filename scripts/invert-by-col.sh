#!/bin/bash

COL=${1:-3}
awk '
    BEGIN {
        clr = 0;
    }
    ($'"${COL}"' != old) {
        old = $'"${COL}"';
        clr = 1 - clr;
    }
    {
        print (clr ? "\033[7m" : ""), $0;
    }
'

#!/bin/bash

COL=${1:-0}
CLR=${2:-soft}
case $CLR in
    inv*|rev*)
        CODE=7
        ;;
    bla*|sof*)
        CODE=40
        ;;
    cy*|har*)
        CODE='30;46'
        ;;
esac
awk '
    BEGIN {
        clr = 0;
    }
    ($'"${COL}"' != old) {
        old = $'"${COL}"';
        clr = 1 - clr;
    }
    {
        print (clr ? "\033['"${CODE}"'m" : ""), $0, "\033[0m";
    }
'

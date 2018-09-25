#!/bin/bash

man tmux | awk '
    ($1 == "Variable" && $2 == "name" && $3 == "Alias" &&
     $4 == "Replaced" && $5 == "with") {
        doprint = 1;
    }
    ($1 == "NAMES" && $2 == "AND" && $3 == "TITLES") {
        exit;
    }
    (doprint) {
        print $0;
    }
'

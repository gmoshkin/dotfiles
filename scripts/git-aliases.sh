#!/usr/bin/env sh

git config --global --get-regexp '^alias.' |
    raku -ne '.words.first.split(".").tail.&{"alias g$_='\''git $_'\''"}.say'

git help -a |
    raku -ne '("alias g$_='\''git $_'\''".say for .words) when /^^ \s\s <[a..z]>/'

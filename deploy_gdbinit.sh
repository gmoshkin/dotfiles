#!/bin/bash

dir="$(dirname $0)"
path="$(readlink -f $dir)"
ln -s "$path/gdbinit" ~/.gdbinit

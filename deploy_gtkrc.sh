#!/bin/bash

dir="$(dirname $0)"
path="$(readlink -f $dir)"
ln -s "$path/gtkrc-2.0" ~/.gtkrc-2.0

#!/bin/bash

options=
if [ -n "$CMUS_ADDR" ]; then
    options+="--listen $CMUS_ADDR"
fi
eval "cmus $options"

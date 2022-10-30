#!/bin/bash

git branch --merged |
    egrep -v '\bmaster\b' |
    xargs git branch -d

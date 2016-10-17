#!/bin/bash

source utils.sh

backup_original ~/.gitconfig
backup_original ~/.gitignore

cat ~/.gitconfig.original ./gitconfig > ~/.gitconfig
cat ~/.gitignore.original ./gitignore > ~/.gitignore

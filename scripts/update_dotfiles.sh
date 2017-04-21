#!/usr/bin/env bash

cd ~/dotfiles
git fetch origin master
git submodule foreach 'git pull origin master'

cd ~/.vim
git fetch origin master

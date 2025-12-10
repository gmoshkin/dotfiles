#!/usr/bin/bash

set -e

THIS_FILE="${BASH_SOURCE[0]}"
THIS_FILE="$(realpath "$THIS_FILE")"
WORK_DIR="$(dirname "$THIS_FILE")"

cd "$WORK_DIR"

echo "Compiling backtrace.rs -> libbacktrace.a"

rustc --crate-type=staticlib -g backtrace.rs

echo "Compiling main.c -> rust-backtrace"

gcc -g main.c -L./ -lbacktrace -o rust-backtrace

echo "Running rust-backtrace"

./rust-backtrace

echo -e "\x1b[32mAll's well\x1b[0m"

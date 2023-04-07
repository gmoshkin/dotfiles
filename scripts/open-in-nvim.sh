#!/bin/bash

filename=$(cat)
cargo \
    --config build.target-dir=\"/tmp/target-nvim-cli\" \
    run --manifest-path ~/dotfiles/scripts/nvim-cli/Cargo.toml &>/dev/null \
    -- open "$filename"

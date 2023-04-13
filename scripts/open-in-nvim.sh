#!/bin/bash

filename=$(cat)
cargo \
    --config build.target-dir=\"/tmp/target-nvim-cli\" \
    run --manifest-path ~/dotfiles/scripts/nvim-cli/Cargo.toml \
    -- open "$filename" \
    &>/dev/null
    # &>>/tmp/open-in-nvim.log

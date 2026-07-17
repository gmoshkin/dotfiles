# Georgy Moshkin's personal dev setup configuration

This repo mostly stores configuration for my dev setup. There's also a separate
sister repo called `dotvim` with my vim/neovim configuration.

Even though I do believe that you could find a bunch of cool, fun and
interesting stuff in this repo, I'm afraid it's going to be hard to discover
these things because of the bad organization in the repo. The first commit in the
repo is dated Oct 10 2016 and since then I have learned a lot, but I pretty much
never pay any time to come up with a good system to organize the repo, I just
fix whatever breaks and add new stuff when I need it. Appologies for the mess!

My dev setup these days consists of these parts:

[alacritty](https://alacritty.org) for the terminal on all of my machines (I
use it on all three linux, WSL on windows and macos). I just need the terminal
to show colored text, my config is minimal and is in `alacritty.toml`.

[tmux](https://github.com/tmux/tmux/wiki) for multitasking/multiplexing or
whatever you call it when you have multiple terminal windows. I have a number
of nice features for my tmux, but I'm not going to tell you about them, sorry.
Files:
- `tmux.conf` - root
- `tmux/*` - extra files
- `jai/tmux-util.jai` - a Jai program which implements a bunch of my utilities
  for tmux including a custom status line

- [neovim](https://neovim.io) for my code editor but also sometimes just `vim` (RIP Bram).
The config is in a different repo for mostly historical reasons https://github.com/gmoshkin/dotvim.

# Deployment

Whenever I need to setup a new machine I spend about a day manually threading
through all the crap using the `deploy.sh` script and other stuff.

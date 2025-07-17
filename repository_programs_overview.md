# Programs in This Repository

This is a dotfiles repository containing configuration files and various custom programs written in multiple programming languages. Here's a comprehensive overview of the programs found:

## Main Categories

### 1. **Shell Scripts and Utilities** (`scripts/` directory)
- **System utilities:**
  - `brightness.py`, `brightness.sh` - Screen brightness control
  - `volume.sh` - Audio volume control
  - `alarm.sh`, `alarms_to_cron.py` - Alarm and cron job management
  - `ps-descendants.sh`, `ps-pane.sh`, `ps-tty.sh` - Process management utilities
  - `tmux-*.sh` - Various tmux session management scripts
  
- **Development tools:**
  - `git-*.sh` - Git workflow utilities (aliases, branch management, stats)
  - `vim-configure.sh` - Vim setup script
  - `ctrlp_cache.sh` - Vim CtrlP cache management
  - `open-in-nvim.sh`, `open-in-vim.sh` - Editor integration scripts

- **Media and graphics:**
  - `img.py`, `kitty_img.py` - Image display utilities
  - `record-screen.sh`, `screenkey.sh` - Screen recording tools
  - `pixels.p6`, `random-pixels.p6` - Pixel manipulation utilities

- **Network and web:**
  - `wttr-get.cpp` - Weather information retrieval
  - `gmail-cpp`, `gmail-cpp.cpp` - Gmail integration
  - `cht.sh` - Cheat sheet utility (12KB script)
  - `trans` - Translation utility (171KB script)

### 2. **Jai Programs** (`jai/` directory)
- **`pageview.jai`** - A sophisticated text viewer/pager (5,216 lines) with features like:
  - Command execution and output viewing
  - File watching capabilities
  - Text search and navigation
  - Completion menu functionality
  
- **System utilities:**
  - `myps` - Custom process viewer
  - `parse.jai` - Text parsing utility
  - `clipboard.jai` - Clipboard management
  - `convert_wsl_paths.jai` - Windows Subsystem for Linux path conversion
  - `aliases.jai` - Command alias system

- **Graphics and GUI:**
  - `window-test.jai` - X11 window testing
  - `x11-*.jai` - Various X11 utilities (keyboard input, transparent windows)
  - `valheim-map.jai` - Game map utility (1,991 lines)

### 3. **Python Programs**
- **`prompt.py`** - Custom shell prompt generator with Unicode box drawing
- **Games and puzzles:**
  - `puzzle-fighter.py` - Puzzle Fighter game logic (262 lines)
  - `triangle.py` - Triangle rendering with barycentric coordinates (278 lines)
  
- **Utilities:**
  - `progress.py` - Progress bar utility
  - `check_currency.py` - Currency checking tool
  - `clip_cutting_cmd.py` - Video clip cutting utility
  - `rotate_matrix.py` - Matrix rotation algorithms (299 lines)
  - `line-intersections.py` - Geometric line intersection calculations

### 4. **Raku/Perl6 Programs**
- **`raku-can-do-it.p6`** - Raku language feature demonstration
- **Graphics and utilities:**
  - `braille.p6` - Braille character manipulation
  - `color-finder.p6`, `color-scheme.p6` - Color utilities
  - `dl.p6` - Download utility (5.8KB)
  - `dynamics.p6` - Dynamic system utilities
  - `cards.p6` - Card game utilities
  - `outcomes.p6` - Probability outcome calculations

### 5. **Rust Programs** (`rust/` directory)
- `rdtsc.rs` - CPU timestamp counter utility
- `rng.rs` - Random number generation (66 lines)
- `tempfile.rs` - Temporary file management
- `type_info.rs` - Type information utility (402 lines)

### 6. **Go Programs** (`go/` directory)
- `hello.go` - Go language example/utility (80 lines)
- `mail.go`, `mail.rs` - Email utilities in Go and Rust

### 7. **Zig Programs** (`zig/` directory)
- `src/main.zig` - Main Zig program
- `src/root.zig` - Root module
- `build.zig` - Build configuration

### 8. **C++ Programs**
- `wttr-get.cpp` - Weather information retrieval
- `gmail-cpp.cpp` - Gmail integration
- `noprintf_truecolor.cpp` - True color output without printf (6.4KB)

### 9. **Configuration Files and Environments**
- **Window managers:** i3, openbox configurations
- **Terminal emulators:** Alacritty, tmux configurations
- **Editors:** Neovim, Vim configurations
- **Shell environments:** Zsh, Bash configurations
- **Development tools:** Git, GDB configurations
- **Game configurations:** Team Fortress 2, Apex Legends settings

### 10. **LeetCode Solutions**
Multiple directories (`leet2/`, `leet4/`, `leet6/`, `leet8/`, `leet10/`, `leetcode-4/`) containing programming competition solutions, including at least one Rust project in `leet10/`.

## Notable Features

- **Multi-language support:** Programs written in Jai, Python, Raku, Rust, Go, Zig, C++, JavaScript, and shell scripts
- **System integration:** Many utilities for Linux desktop environment management
- **Game development:** Graphics programming, game utilities, and game configuration files
- **Development workflow:** Git utilities, editor integrations, and build tools
- **Graphics programming:** Pixel manipulation, triangle rendering, and color utilities

This repository represents a comprehensive collection of personal tools and utilities spanning system administration, development workflows, graphics programming, and gaming configurations.
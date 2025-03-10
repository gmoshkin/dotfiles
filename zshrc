#
# Function-level profiling
#
# zmodload zsh/zprof

#
# Command-level profiling
#
# Source: https://stackoverflow.com/a/4351664/2103996
#
# {{{

# zmodload zsh/datetime
# setopt promptsubst
# PS4='[$EPOCHREALTIME] %N:%i> '
# exec 3>&2 2> /tmp/prof-cmd.$$
# setopt xtrace prompt_subst

# }}}

# Lines configured by zsh-newuser-install
setopt appendhistory autocd extendedglob nomatch notify histignorealldups
setopt interactivecomments
REPORTTIME=3
unsetopt beep
bindkey -e
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/home/gmoshkin/.zshrc'

autoload -Uz compinit
compinit

autoload -Uz promptinit
promptinit

prompt mine

autoload -U select-word-style
select-word-style bash


/usr/bin/df -B1024 | awk \
'   /C:\\/ {
        if ($4 < 10 * 1024 * 1024) {
            print("\x1b[31m################################################################")
            print("!!!         Disk C:\\ has less then 10G of space left         !!!")
            print("!!!         Only ", $4 / 1024, "M is left                           !!!")
            print("################################################################\x1b[0m")
        }
    }
'


source "$DOTFILES/commands.sh"

2>/dev/null hash dircolors && eval `dircolors ~/.dir_colors/dircolors`
2>/dev/null hash gdircolors && eval `gdircolors ~/.dir_colors/dircolors`
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}

alias SZ="source ~/.zshrc && source ~/.zshenv"

bindkey "^U" backward-kill-line
bindkey "^\\" redo

# disable c-s binding (stop/start output control)
stty -ixon

source "$DOTFILES/utils.sh"
appendToPath "$DOTFILES/scripts"
prependToPath "$HOME/.cargo/bin"
appendToPath "$HOME/.perl6/bin"
prependToPath "$HOME/.local/go/bin"
prependToPath "$HOME/.local/share/perl6/site/bin"
appendToPath "$HOME/.rakubrew/bin"
prependToPath "$HOME/.local/bin"
appendToPath "$HOME/code/table-driven-testing-tool/target/debug"
prependToPath "$HOME/gocode/bin"
appendToPath "$HOME/.rocks/bin"
prependToPath "/opt/homebrew/opt/llvm/bin"
prependToPath "/opt/homebrew/bin"
prependToPath "$HOME/.nimble/bin"
prependToPath "$HOME/.cargo-target/release"
prependToPath "$HOME/.cargo-target/debug"
prependToPath "$DOTFILES/jai"
for drive in {c..d}; [ -d "/mnt/$drive/jai/bin" ] && prependToPath "/mnt/$drive/jai/bin"
for drive in {c..d}; [ -d "/mnt/$drive/tools/raddbg_0.9.14b" ] && prependToPath "/mnt/$drive/tools/raddbg_0.9.14b"

# too slow
# source "$DOTFILES/rakubrew_init.zsh"
# rakubrew switch &>/dev/null

source "$DOTFILES/aliases.sh"

local hlfiles=(
    /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
    /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
    /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
    /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
    /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
)
for hlfile in  ${hlfiles[@]};
    [ -f "$hlfile" ] && source "$hlfile"

export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=8"

alias SB='source ~/.zshrc'

source "$DOTFILES/fzf-init.sh" && {
    bindkey '^T' transpose-chars;
    bindkey '^O' fzf-file-widget;
} || {
    echo 'fzf is not installed'
}

[ -f /usr/share/z/z.sh ] && source /usr/share/z/z.sh

export WORKON_HOME="${HOME}/.virtualenvs"
[ -f /usr/bin/virtualenvwrapper.sh ] && source /usr/bin/virtualenvwrapper.sh
[ -d "${WORKON_HOME}" ] || mkdir "${WORKON_HOME}"

# too slow
# eval "$(pip completion --zsh)"

# End of lines added by compinstall

HOMEBREW_LLVM_PATH=/opt/homebrew/opt/llvm
[ -d "${HOMEBREW_LLVM_PATH}" ] && {
    export LDFLAGS="-L${HOMEBREW_LLVM_PATH}/lib"
    export CPPFLAGS="-I${HOMEBREW_LLVM_PATH}/include"
}

export LUA_PATH="$DOTFILES/scripts/?.lua;/usr/share/luajit-2.1.0-beta3/?.lua"
export LUA_CPATH="./target/debug/lib?.so;./target/release/lib?.so;$HOME/.cargo-target/debug/lib?.so;$HOME/.cargo-target/release/lib?.so"
export PYTHONPATH="$DOTFILES/scripts"
export DISPLAY_PROXY="$(/sbin/ip route | awk '/^default/ { print $3 }'):0"

# Dump the function-level profiling info.
# zprof > /tmp/prof-func.$$

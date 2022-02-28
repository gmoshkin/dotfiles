#!/usr/bin/env bash

error() { >&2 echo -e "\x1b[31m===ERROR===\x1b[0m" $@; }
info() { echo -e "\x1b[34m===INFO===\x1b[0m" $@; }
warn() { echo -e "\x1b[33m===WARNING===\x1b[0m" $@; }
die() { >&2 error $@; exit 1; }

################################################################################
## start

cd ~

################################################################################
## apt packages

info "getting 'apt' packages"

sudo apt update;
sudo apt upgrade;
sudo apt install \
    curl \
    build-essential \
    cmake \
    ninja-build \
    libssl-dev libncurses5-dev libreadline-dev libunwind-dev libicu-dev \
    rlwrap \
    tmux \
    clang \
    golang \
    jq \
    ripgrep \
    ranger \
    zsh zsh-syntax-highlighting zsh-autosuggestions \
    vim \
    ruby \
    python3 python3-pip python-is-python3 \
    luajit libluajit-5.1-dev luarocks \
    || die "failed to get apt packages"

################################################################################
## pip packages

info "getting 'pip' packages"

hash pip 2>/dev/null && {
    info "'pip' already installed: $(which pip)";
} || {
    pip install --user \
        ipython \
        gevent \
        || die "faile to get pip packages";
}

################################################################################
## rustup

info "getting 'rustup'"

[ -f ~/.cargo/bin/rustup ] && {
    info "'rustup' is already present: $(which rustup)";
} || {
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh \
        || die "couldn't get 'rustup'";

    ~/.cargo/bin/rustup toolchain install nightly \
        || die "failed to install nightly toolchain";
}

################################################################################
## ~/.local

[ -d ~/.local ] || mkdir ~/.local

################################################################################
## nvim

info "getting 'nvim'"

hash nvim 2>/dev/null && {
    info "'nvim' already installed: $(which nvim)";
} || {
    pushd /tmp;
    wget https://github.com/neovim/neovim/releases/download/stable/nvim-linux64.tar.gz;
    tar xf nvim-linux64.tar.gz;
    cp -r nvim-linux64/* ~/.local/;
    rm -r nvim-linux64*;
    popd;
}

################################################################################
## node

info "getting 'node'"

hash node 2>/dev/null && {
    info "'node' already installed: $(which node)";
} || {
    pushd /tmp;
    NODE_VERSION=${NODE_VERSION-v16.13.0}
    NODE_ARCHIVE="${NODE_ARCHIVE-node-${NODE_VERSION}-linux-x64}"
    wget "https://nodejs.org/dist/${NODE_VERSION}/${NODE_ARCHIVE}.tar.xz";
    tar xf "${NODE_ARCHIVE}.tar.xz";
    cp -r "${NODE_ARCHIVE}"/* ~/.local/;
    rm -r "${NODE_ARCHIVE}"{,.tar.xz};
    popd;
}

exit 0

################################################################################
## ssh keys

info "setting up ssh keys"

[ -f ~/.ssh/id_rsa.pub ] && {
    info "ssh key already present: $(ls $HOME/.ssh/id_rsa* | tr '\n' ' ')";
} || {
    ssh-keygen;
    info "add this key to github and press <cr> to proceed";
    cat ~/.ssh/id_rsa.pub;
    read
}

################################################################################
## dotfiles

repo=dotfiles
dir="$HOME/$repo"
info "cloning '$repo' into '$dir'"

[ -d "$dir" ] && {
    echo "'$dir' exists, won't clone";
} || {
    git clone --recursive "git@github.com:gmoshkin/$repo.git" "$dir" \
        || die "Couldn't clone '$repo'. Make sure ssh key is added to github";
}

################################################################################
## .vim

repo=dotvim
dir="$HOME/.vim"
info "cloning '$repo' into '$dir'"

[ -d "$dir" ] && {
    echo "'$dir' exists, won't clone";
} || {
    git clone "git@github.com:gmoshkin/$repo.git" "$dir" \
        || die "Couldn't clone '$repo'";
}

################################################################################
## plug.vim

dir="$HOME/.vim/bundle"
file="plug.vim"
info "getting '$file' into '$dir'"

[ -f "$dir/$file" ] && {
    info "'$file' already exists: $(ls $dir/$file)";
} || {
    curl -fLo "$dir/$file" --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/$file \
            || die "failed to get 'plug.vim";

    echo | vim +PlugInstall +qall \
        || die "failed to install vim plugins";

    grep 'fzf.bash' ~/.bashrc && sed '/fzf/d' -i ~/.bashrc;
    grep 'fzf.zsh' ~/.zshrc && sed '/fzf/d' -i ~/.zshrc;
}

################################################################################
## dotfiles -> deploy.sh

cd dotfiles
for target in \
    bashrc \
    gitconfig \
    dircolors \
    gdbinit \
    gitignore \
    tmux_conf \
    cmus \
    lesskey \
    htoprc \
    ranger \
    radare2 \
    zsh \
    kak \
    nvim \
; {
    ./deploy.sh $target \
        || warn "couldn't deploy '$target'";
}

################################################################################
## rakubrew

# XXX: latest changes aren't tested yet

RAKU_TOOL=rakubrew
RAKU_URL="https://${RAKU_TOOL}.org/install-on-perl.sh"
RAKU_ROOT="$HOME/.${RAKU_TOOL}"
RAKU_INIT="$HOME/dotfiles/${RAKU_TOOL}_init.bash"

[ hash raku 2>/dev/null ] && {
    info "'raku' exists, won't build";
} || {
    [ -d "${RAKU_ROOT}" ] || {
        curl "${RAKU_URL}" | sh \
            || die "failed to download ${RAKU_TOOL}";
    };
    export PATH="$PATH:${RAKU_ROOT}/bin";
    source "$RAKU_INIT";

    [ -d "${RAKU_ROOT}/versions/moar-blead" ] && {
        info "raku moar-blead already built";
    } || {
        "$RAKU_TOOL" build moar-blead \
            || die "failed to build 'raku moar-blead'";
    }
    "$RAKU_TOOL" switch moar-blead;
    "$RAKU_TOOL" build-zef \
        || die "failed to build 'zef'";
}

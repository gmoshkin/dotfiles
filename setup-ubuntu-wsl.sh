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
    rlwrap \
    tmux \
    golang \
    jq \
    ripgrep \
    ranger \
    zsh zsh-syntax-highlighting zsh-autosuggestions \
    vim \
    nodejs \
    ruby \
    python3 python3-pip python-is-python3 \
    || die "failed to get apt packages"

################################################################################
## pip packages

info "getting 'pip' packages"

hash pip 2>/dev/null && {
    info "'pip' already installed: $(which pip)";
} || {
    pip install --user \
        ipython \
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
## rakudobrew

[ hash raku 2>/dev/null ] && {
    info "'raku' exists, won't build";
} || {
    export PATH="$PATH:$HOME/dotfiles/rakudobrew/bin";
    source ~/dotfiles/rakudobrew_init.bash;

    [ -d ~/dotfiles/rakudobrew/versions/moar-blead ] && {
        info "raku moar-blead already built";
    } || {
        rakudobrew build moar-blead \
            || die "failed to build 'raku moar-blead'";
    }
    rakudobrew switch moar-blead;
    rakudobrew build-zef \
        || die "failed to build 'zef'";
}

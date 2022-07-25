alias g='git'
cargo run --manifest-path $HOME/dotfiles/scripts/aliases/Cargo.toml \
    2>/dev/null |
        while read alias; do
            eval $alias;
        done

alias pst='ps Tf'
alias psl='ps -A f | less'
alias lgrep='less-grep'
alias watch='watch --color -n 1'
alias cput='xsel --clipboard'
alias cget='cat | xsel --clipboard'
alias O='xdg-open'
alias gitstashpull='git stash && git pull && git stash pop'
alias ll='ls -lh'
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias iraku='jupyter-console --kernel=raku'
alias df='df -h'
alias rwp='rlwrap perl6'
alias rb="ruby -I$HOME/dotfiles/scripts -rmine"
alias irb="irb -I$HOME/dotfiles/scripts -rmine"

case $OSTYPE in
    darwin*)
        NPROC=$(sysctl -n hw.ncpu)
        ;;
    linux*)
        NPROC=$(nproc)
        ;;
    *)
        >&2 echo === Uknown OSTYPE: $OSTYPE ===;
        NPROC=4 # let's hope for the best
esac

alias ct="cargo test -- --test-threads=${NPROC}"

alias cbr='cargo build --release'

NJOBS="$(( ( ${NPROC} * 3 + 5 - 1 ) / 5 ))" # (x * a + b - 1) / b == ceiling(x * a/b)

alias cmgui="cmake \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=1 \
    -C ../preset/ubuntu1910.cmake .. && \
        make -j$NJOBS"
alias cmweb="source ../deps/work/emscripten/*/src/emsdk_env.sh && \
    export EMSCRIPTEN=\$PWD/../deps/work/emscripten/*/src/fastcomp/emscripten && \
    cmake \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=1 \
    -C ../preset/ubuntu1604-emscripten-wasm.cmake .. && \
        make -j$NJOBS"
alias cmguirel="cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=1 \
    -C ../preset/ubuntu1910.cmake .. && \
        make -j$NJOBS"
alias cmwebrel="source ../deps/work/emscripten/*/src/emsdk_env.sh && \
    export EMSCRIPTEN=\$PWD/../deps/work/emscripten/*/src/fastcomp/emscripten && \
    cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=1 \
    -C ../preset/ubuntu1604-emscripten-wasm.cmake .. && \
        make -j$NJOBS"
alias runweb="git rev-parse --git-dir &>/dev/null && \
    cd \"\$(git rev-parse --show-toplevel)/build-web/bin\" && { \
    [ -f index.html ] || ln -s ../../docker/frontend/poormans/index.html; \
    xdg-open http://localhost:8000; \
    python3 -m http.server; \
} || echo 'Not inside repository'"
alias runfatty="git rev-parse --git-dir &>/dev/null && \
    cd \"\$(git rev-parse --show-toplevel)/build/bin\" && { \
    [ -d img ] || ln -s ../../lde/editor/img; \
    [ -d res ] || ln -s ../../lde/fatty/res; \
    ./fatty \
} || echo 'Not inside repository'"
alias runfattyrel="git rev-parse --git-dir &>/dev/null && \
    cd \"\$(git rev-parse --show-toplevel)/build-rel/bin\" && { \
    [ -d img ] || ln -s ../../lde/editor/img; \
    [ -d res ] || ln -s ../../lde/fatty/res; \
    ./fatty \
} || echo 'Not inside repository'"

# GitBash and Msys2 must be installed and the ssh keys must be set in one of
# their home directories
alias winsh='/mnt/c/msys64/usr/bin/bash.exe'
alias wgf="winsh -c 'git fetch'"
alias wgpu="winsh -c 'git push -u origin \$(git rev-parse --abbrev-ref HEAD)'"
alias wgpf="winsh -c 'git push -f'"

alias carkill="cartridge stop"
alias carstart="cartridge start"
alias carinfo="cartridge status"
alias carbuild="cartridge build"
alias carreplicasets="cartridge replicasets"

alias ipython3.10="python3.10 -m IPython"

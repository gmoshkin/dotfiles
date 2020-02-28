alias g='git'
git config --global --get-regexp '^alias.' |
    raku -ne '.words.first.split(".").tail.&{"alias g$_='\''git $_'\''"}.say' |
    while read git_alias; do
        eval $git_alias;
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
alias iperl6='jupyter-console --kernel=perl6'
alias df='df -h'
alias rwp='rlwrap perl6'

NJOBS=8
alias cmgui='cmake \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=1 \
    -C ../preset/ubuntu1910.cmake .. && \
        make -j'"$NJOBS"
alias cmweb='source ../deps/work/emscripten/*/src/emsdk_env.sh \
    cmake \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=1 \
    -C ../preset/ubuntu1604-emscripten-wasm.cmake .. && \
        make -j'"$NJOBS"
alias cmguirel='cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=1 \
    -C ../preset/ubuntu1910.cmake .. && \
        make -j'"$NJOBS"
alias cmwebrel='source ../deps/work/emscripten/*/src/emsdk_env.sh \
    cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=1 \
    -C ../preset/ubuntu1604-emscripten-wasm.cmake .. && \
        make -j'"$NJOBS"
alias runweb='git rev-parse --git-dir &>/dev/null && \
    cd "$(git rev-parse --show-toplevel)/build-web/bin" && {
    [ -f index.html ] || ln -s ../../docker/frontend/poormans/index.html;
    xdg-open http://localhost:8000;
    python3 -m http.server;
} || echo "Not inside repository"'

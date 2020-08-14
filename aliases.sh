alias g='git'
{
    git config --global --get-regexp '^alias.' |
        raku -ne '.words.first.split(".").tail.&{"alias g$_='\''git $_'\''"}.say';
    raku -e '"/usr/lib/git-core".IO.dir.grep({.x and !.d}).map: {
        .basename.subst("git-").&{"alias g$_='\''git $_'\''"}.say
    }';
} | while read git_alias; do
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
alias iraku='jupyter-console --kernel=raku'
alias df='df -h'
alias rwp='rlwrap perl6'

{
    raku -e '<build check new init run search test update>.map: {
        say "alias c{.substr(0, 1)}=\"cargo $_\""
    }';
    cargo --list |
        raku -ne '
            when /Installed/ { next };
            my $c = .words.first;
            say "alias c$c=\"cargo $c\""
        ';
} | while read cargo_alias; do
        eval $cargo_alias;
    done

NJOBS="$(raku -e 'say ceiling qx[nproc] * .6')"

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

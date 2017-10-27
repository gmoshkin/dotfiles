#!/usr/bin/env bash

function __log {
    echo '*** '$@
}

function update_repo {
    git fetch origin master

    commits_count=$(git rev-list --left-right --count HEAD...origin/HEAD)
    our_commits=${commits_count/%	*/}
    their_commits=${commits_count/#*	/}

    if [ "$their_commits" -gt 0 ]; then
        __log "new commits on origin, pulling..."
        mod=$(git status --porcelain --ignore-submodules=all | grep '^\s*M ' | wc -l)
        if [ "$mod" -gt 0 ]; then
            __log "stashing first..."
            git stash
        fi
        __log "pulling..."
        git pull --rebase origin master
        if [ "$mod" -gt 0 ]; then
            __log "now popping the stash..."
            git stash pop
        fi
        if git status --porcelain | grep '^UU'; then
            __log "conflicts after pop in $(pwd)"
            source ~/dotfiles/commands.sh && integram "merge conflict in $(pwd)"
        else
            __log "successfully pulled"
        fi
        __log "done pulling"
    fi

    if [ "$our_commits" -gt 0 ]; then
        __log "new commits locally, pushing..."
        git push
        __log "done pushing"
    fi
}

cd ~/dotfiles
__log "updating dotfiles..."
update_repo

__log "updating submodules..."
# if any new submodules were added we have to init them and check them out
# and fetch the latest version of the remote branch while we're at it
git submodule update --init --remote
# update just detached all the heads so we'll go ahead a reattach 'em back
git submodule foreach 'git checkout -B master'

cd ~/.vim
__log "updating vimfiles..."
update_repo

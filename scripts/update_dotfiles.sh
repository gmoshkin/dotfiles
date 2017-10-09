#!/usr/bin/env bash

function update_repo {
    git fetch origin master

    commits_count=$(git rev-list --left-right --count HEAD...origin/HEAD)
    our_commits=${commits_count/%	*/}
    their_commits=${commits_count/#*	/}

    if [ "$their_commits" -gt 0 ]; then
        echo "new commits on origin, pulling..."
        mod=$(git status --porcelain --ignore-submodules=all | grep '^\s*M ' | wc -l)
        if [ "$mod" = 0 ]; then
            git stash
        fi
        git pull --rebase origin master
        if [ "$mod" = 0 ]; then
            git stash pop
        fi
        if git status --porcelain | grep '^UU'; then
            source ~/dotfiles/commands.sh && integram "merge conflict in $(pwd)"
        fi
    fi

    if [ "$our_commits" -gt 0 ]; then
        echo "new commits locally, pushing..."
        git push
    fi
}

cd ~/dotfiles
echo "updating dotfiles..."
update_repo

echo "updating submodules..."
# if any new submodules were added we have to init them and check them out
# and fetch the latest version of the remote branch while we're at it
git submodule update --init --remote
# update just detached all the heads so we'll go ahead a reattach 'em back
git submodule foreach 'git checkout -B master'

cd ~/.vim
echo "updating vimfiles..."
update_repo

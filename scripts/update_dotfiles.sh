#!/usr/bin/env bash

function update_repo {
    git fetch origin master

    commits_count=$(git rev-list --left-right --count HEAD...origin/HEAD)
    our_commits=${commits_count/%	*/}
    their_commits=${commits_count/#*	/}

    if [ "$their_commits" -gt 0 ]; then
        echo "new commits on origin, pulling..."
        git stash && git pull --rebase origin master && git stash pop
        if git status | grep 'both modified'; then
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
git submodule foreach 'git pull origin master'

cd ~/.vim
echo "updating vimfiles..."
update_repo

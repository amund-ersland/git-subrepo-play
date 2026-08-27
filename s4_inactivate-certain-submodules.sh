#!/bin/bash
set -eo pipefail

_PWD=$PWD

for u in utils/*; do
    source $u
done

TITLE "This script demonstrates updating submodules recursively with the remote flag to get the newest commit of the submodule"

LAYERS=2
REPOS_PER_LAYER=2
prefix="$(echo $0 | cut -d _ -f 1 | cut -d / -f 2)"
STDOUT_PAUSE "Setup repos in $LAYERS with $REPOS_PER_LAYER in each"
setup_layered_repos $prefix $LAYERS $REPOS_PER_LAYER

#PAUSE "user1 adds a file to grandchild-repo"
#make_commit "$root_dir/user1/parent-repo/child-repo/grandchild-repo"
#
#PAUSE "user1 adds a file to child-repo"
#make_commit "$root_dir/user1/parent-repo/child-repo"
#
#PAUSE "user2 pulls all the updates fetching the latest remotes"
#update_remote_recursive $root_dir/user2/parent-repo
#
#PAUSE "Print status for user 1 and 2 for the repos"
#repo_status $root_dir/user1/parent-repo child-repo user1
#repo_status $root_dir/user2/parent-repo child-repo user2
#repo_status $root_dir/user1/parent-repo/child-repo grandchild-repo user1
#repo_status $root_dir/user2/parent-repo/child-repo grandchild-repo user2

cd $_PWD

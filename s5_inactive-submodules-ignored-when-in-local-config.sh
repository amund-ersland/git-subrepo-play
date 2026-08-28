#!/bin/bash
set -eo pipefail

# Set to true to run non-interactively (skip all pauses)
SKIP_PAUSE=false

_PWD=$PWD

for u in utils/*; do
    source $u
done

TITLE "This script demonstrates updating submodules recursively with the remote flag to get the newest commit of the submodule"

LAYERS=2
REPOS_PER_LAYER=2
prefix="$(echo $0 | cut -d _ -f 1 | cut -d / -f 2)"
STDOUT_PAUSE "Setup repos in $LAYERS with $REPOS_PER_LAYER in each"
setup_layered_repos $prefix $LAYERS $REPOS_PER_LAYER "skip-user2"

PAUSE "user2 clones repo and set child-2 to inactive in local git config"
clone $remote_dir/parent-repo $root_dir/user2
PAUSE "Content of user2 parent-repo: $(tree $root_dir/user2/parent-repo)"
set_submodule_status $root_dir/user2/parent-repo child-repo-2 inactive config
print_submodule_active_status "$root_dir/user2/parent-repo" "config"

update_init_recursive $root_dir/user2/parent-repo
PAUSE "Print status for user 1 and 2 for the repos"

for u in 1 2; do
    for c in 1 2; do
        repo_status $root_dir/user$u/parent-repo \
            child-repo-$c \
            "user$u child-repo-$c"
    done
done

cd $_PWD

#!/bin/bash
set -eo pipefail

_PWD=$PWD

for u in utils/*; do source $u; done

parse_args "$@"

TITLE "This script demonstrates updating submodules recursively to get the same commits as pointet to by the superproject"

LAYERS=2
prefix="$(echo $0 | cut -d _ -f 1 | cut -d / -f 2)"
STDOUT_PAUSE "Setup repos in $LAYERS layers"
setup_layered_repos $prefix $LAYERS

PAUSE "user1 adds a file to child repo"
commit_file "$root_dir/user1/parent-repo/child-repo"

PAUSE "user1 updates parent repo with newest commit in child repo"
    update_superproject_with_submodule $root_dir/user1/parent-repo child-repo

PAUSE "user2 pulls all the updates"
update_init_recursive $root_dir/user2/parent-repo

PAUSE "Print status for user1 and user2"
repo_status $root_dir/user1/parent-repo child-repo user1
repo_status $root_dir/user2/parent-repo child-repo user2

cd $_PWD

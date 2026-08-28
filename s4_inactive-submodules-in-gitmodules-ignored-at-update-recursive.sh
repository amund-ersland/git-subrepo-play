#!/bin/bash
set -eo pipefail

_PWD=$PWD

for u in utils/*; do source $u; done

parse_args "$@"

TITLE "This script demonstrates updating submodules recursively with the remote flag to get the newest commit of the submodule"

LAYERS=2
REPOS_PER_LAYER=2
prefix="$(echo $0 | cut -d _ -f 1 | cut -d / -f 2)"
STDOUT_PAUSE "Setup repos in $LAYERS with $REPOS_PER_LAYER in each"
setup_layered_repos $prefix $LAYERS $REPOS_PER_LAYER "skip-user2"

PAUSE "user1 makes a commit in child-repo-1 and 2"
superproject="$root_dir/user1/parent-repo"
for c in 1 2; do 
    commit_file "$superproject/child-repo-$c"
    update_superproject_with_submodule "$superproject" "child-repo-$c"
done

PAUSE "user1 sets child-repo-2 to inactive"
set_submodule_status "$root_dir/user1/parent-repo" child-repo-2 inactive
print_submodule_active_status "$root_dir/user1/parent-repo"

PAUSE "user1 commits this update to origin"
commit_gitmodules "$root_dir/user1/parent-repo"

PAUSE "user2 clones repo and still gets child-2"
clone $remote_dir/parent-repo $root_dir/user2
print_submodule_active_status "$root_dir/user2/parent-repo"
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

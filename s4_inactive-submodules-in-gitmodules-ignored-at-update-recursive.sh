#!/bin/bash
set -eo pipefail

# define constants
LAYERS=2
REPOS_PER_LAYER=2
NUM_USERS=2

# save current pwd for return
_PWD=$PWD

# parse args and utils
for u in utils/*; do source $u; done
parse_args "$@"

# start script
TITLE "This script demonstrates that an inactive (active=false) flag in .gitmodules is ignored by 'submodule update --init', which re-activates and updates every submodule"

STDOUT_PAUSE "Setup repos in $LAYERS with $REPOS_PER_LAYER in each"

prefix="$(echo $0 | cut -d _ -f 1 | cut -d / -f 2)"
create_submodule_hierarchy $prefix $LAYERS $REPOS_PER_LAYER "skip-user2"

PAUSE "user1 makes a commit in child-repo-1 and 2"
superproject="$root_dir/user1/parent-repo"
for c in 1 2; do
    add_random_file_and_push "$superproject/child-repo-$c"
    update_superproject_with_submodule "$superproject" "child-repo-$c"
done

PAUSE "user1 sets child-repo-2 to inactive"
set_submodule_active "$root_dir/user1/parent-repo" child-repo-2 inactive
print_submodule_active_flags "$root_dir/user1/parent-repo"

PAUSE "user1 commits this update to origin"
commit_push_gitmodules "$root_dir/user1/parent-repo"

PAUSE "user2 clones repo and still gets child-2"
clone_repo $remote_dir/parent-repo $root_dir/user2
print_submodule_active_flags "$root_dir/user2/parent-repo"
print_submodule_active_flags "$root_dir/user2/parent-repo" "config"
update_submodules $root_dir/user2/parent-repo --init
PAUSE "Print status for user 1 and 2 for the repos"

print_repo_statuses $NUM_USERS $REPOS_PER_LAYER

PAUSE "🧪 Run tests"

INFO "🧪 TEST: child-repo-1 of user1 vs user2 → should be EQUAL. child-repo-1 was never marked inactive, so user2's 'submodule update --init --recursive' checks it out at the recorded commit."
assert_sha_equal "$root_dir/user1/parent-repo/child-repo-1" "$root_dir/user2/parent-repo/child-repo-1"

INFO "🧪 TEST: child-repo-2 of user1 vs user2 → should be EQUAL even though it is marked active=false in .gitmodules. The 'active' flag in .gitmodules is IGNORED by 'submodule update --init', because --init re-activates every submodule before updating."
assert_sha_equal "$root_dir/user1/parent-repo/child-repo-2" "$root_dir/user2/parent-repo/child-repo-2"

# return to start folder
cd $_PWD

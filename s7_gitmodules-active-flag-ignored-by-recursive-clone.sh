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
TITLE "This script busts a common misconception: setting active=false in .gitmodules does NOT stop colleagues from getting a submodule. A plain 'git clone --recurse-submodules' is documented as equivalent to 'submodule update --init --recursive' and sets submodule.active='.', so it re-activates and checks out every submodule anyway."

STDOUT_PAUSE "Setup repos in $LAYERS with $REPOS_PER_LAYER in each"

prefix="$(echo $0 | cut -d _ -f 1 | cut -d / -f 2)"
create_submodule_hierarchy $prefix $LAYERS $REPOS_PER_LAYER "skip-user2"

PAUSE "user1 makes a commit in child-repo-1 and 2"
superproject="$root_dir/user1/parent-repo"
for c in 1 2; do
    add_random_file_and_push "$superproject/child-repo-$c"
    update_superproject_with_submodule "$superproject" "child-repo-$c"
done

PAUSE "user1 sets child-repo-2 to inactive in .gitmodules, hoping others won't get it"
set_submodule_active "$root_dir/user1/parent-repo" child-repo-2 inactive
print_submodule_active_flags "$root_dir/user1/parent-repo"

PAUSE "user1 commits this update to origin"
commit_push_gitmodules "$root_dir/user1/parent-repo"

PAUSE "user2 clones RECURSIVELY (the normal way to onboard) and still gets child-repo-2"
clone_repo $remote_dir/parent-repo $root_dir/user2 --recursive
print_submodule_active_flags "$root_dir/user2/parent-repo" "gitmodules"
print_submodule_active_flags "$root_dir/user2/parent-repo" "config"
PAUSE "Print status for user 1 and 2 for the repos"

print_repo_statuses $NUM_USERS $REPOS_PER_LAYER

PAUSE "🧪 Run tests"

INFO "🧪 TEST: child-repo-1 of user1 vs user2 → should be EQUAL. child-repo-1 was never marked inactive, so the recursive clone checked it out at the recorded commit."
assert_sha_equal "$root_dir/user1/parent-repo/child-repo-1" "$root_dir/user2/parent-repo/child-repo-1"

INFO "🧪 TEST: child-repo-2 of user1 vs user2 → should be EQUAL even though it is active=false in .gitmodules. 'git clone --recurse-submodules' is equivalent to 'submodule update --init --recursive' and sets submodule.active='.' in user2's local config, so the .gitmodules active flag is IGNORED and child-repo-2 is checked out anyway."
assert_sha_equal "$root_dir/user1/parent-repo/child-repo-2" "$root_dir/user2/parent-repo/child-repo-2"

INFO "ℹ️  NOTE: To actually keep a colleague from getting a submodule, use LOCAL config active=false without --init (see s5), or exclude it at clone time with a pathspec (see s6). The active flag in .gitmodules alone will not do it."

# return to start folder
cd $_PWD

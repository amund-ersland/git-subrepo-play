#!/bin/bash
set -eo pipefail

# define constants
LAYERS=2
NUM_USERS=2

# save current pwd for return
_PWD=$PWD

# parse args and utils
for u in utils/*; do source $u; done
parse_args "$@"

# start script
TITLE "This script demonstrates updating submodules recursively to get the same commits as pointed to by the superproject"

prefix="$(echo $0 | cut -d _ -f 1 | cut -d / -f 2)"
STEP "Set up repos in $LAYERS layers"
create_submodule_hierarchy $prefix $LAYERS

STEP "user1 adds a file to child repo"
add_random_file_and_push "$root_dir/user1/parent-repo/child-repo"

STEP "user1 updates parent repo with newest commit in child repo"
update_superproject_with_submodule $root_dir/user1/parent-repo child-repo

STEP "user2 pulls all the updates"
user2_child_before=$(current_sha "$root_dir/user2/parent-repo/child-repo")
update_submodules $root_dir/user2/parent-repo

STEP "Print status for user1 and user2"
print_repo_statuses $NUM_USERS 1

STEP "🧪 Run tests"

INFO "🧪 TEST: child-repo of user1 vs user2 → should be EQUAL, because user1 pushed a new child-repo commit + bumped the superproject pointer, and user2 ran 'submodule update --init --recursive' which checks out that exact recorded commit."
assert_sha_equal "$root_dir/user1/parent-repo/child-repo" "$root_dir/user2/parent-repo/child-repo"

INFO "🧪 TEST: parent-repo of user1 vs user2 → should be EQUAL, because user2 pulled the superproject commit in which user1 recorded the updated child-repo pointer."
assert_sha_equal "$root_dir/user1/parent-repo" "$root_dir/user2/parent-repo"

INFO "🧪 TEST: user2's child-repo advanced from its pre-update commit → 'submodule update' actually moved the working tree, it was not already there."
assert_sha_advanced "$root_dir/user2/parent-repo/child-repo" "$user2_child_before"

INFO "🧪 TEST: user2's child-repo HEAD == the pointer recorded in user2's parent-repo → a default (non --remote) update checks out exactly the RECORDED gitlink, which is the whole point of this workflow."
assert_submodule_matches_gitlink "$root_dir/user2/parent-repo" child-repo

INFO "🧪 TEST: user2's working trees are clean after the update."
assert_clean_worktree "$root_dir/user2/parent-repo"
assert_clean_worktree "$root_dir/user2/parent-repo/child-repo"

cd $_PWD

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
update_submodules $root_dir/user2/parent-repo

STEP "Print status for user1 and user2"
print_repo_statuses $NUM_USERS 1

STEP "🧪 Run tests"

INFO "🧪 TEST: child-repo of user1 vs user2 → should be EQUAL, because user1 pushed a new child-repo commit + bumped the superproject pointer, and user2 ran 'submodule update --init --recursive' which checks out that exact recorded commit."
assert_sha_equal "$root_dir/user1/parent-repo/child-repo" "$root_dir/user2/parent-repo/child-repo"

INFO "🧪 TEST: parent-repo of user1 vs user2 → should be EQUAL, because user2 pulled the superproject commit in which user1 recorded the updated child-repo pointer."
assert_sha_equal "$root_dir/user1/parent-repo" "$root_dir/user2/parent-repo"

cd $_PWD

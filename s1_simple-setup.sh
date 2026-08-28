#!/bin/bash
set -eo pipefail

# define constants
LAYERS=2

# save current pwd for return
_PWD=$PWD

# parse args and utils
for u in utils/*; do source $u; done
parse_args "$@"

# start script
TITLE "This script demonstrates the setup of a nested repo and cloning for a second user"
prefix="$(echo $0 | cut -d _ -f 1 | cut -d / -f 2)"

STEP "Set up a nested repo hierarchy in $LAYERS layers and clone it for user2"
create_submodule_hierarchy $prefix $LAYERS

STEP "🧪 Run tests"

INFO "🧪 TEST: parent-repo of user1 vs user2 → should be EQUAL, because user2 cloned the same parent-repo remote that user1 pushed, so both point at the same superproject commit."
assert_sha_equal "$root_dir/user1/parent-repo" "$root_dir/user2/parent-repo"

INFO "🧪 TEST: child-repo submodule of user1 vs user2 → should be EQUAL, because user2 cloned --recursive and thus checked out the exact submodule commit recorded by the parent-repo."
assert_sha_equal "$root_dir/user1/parent-repo/child-repo" "$root_dir/user2/parent-repo/child-repo"

INFO "🧪 TEST: user2's child-repo is actually INITIALIZED → a recursive clone must leave a .git link in the submodule working tree, proving it was activated and checked out (not just an empty gitlink dir)."
assert_submodule_initialized "$root_dir/user2/parent-repo" child-repo

INFO "🧪 TEST: user2's checked-out child-repo HEAD == the pointer RECORDED in user2's parent-repo → a recursive clone checks out exactly the commit the superproject records, not merely the same commit as user1."
assert_submodule_matches_gitlink "$root_dir/user2/parent-repo" child-repo

INFO "🧪 TEST: both working trees are clean → the clone/checkout left no stray or modified files."
assert_clean_worktree "$root_dir/user2/parent-repo"
assert_clean_worktree "$root_dir/user2/parent-repo/child-repo"

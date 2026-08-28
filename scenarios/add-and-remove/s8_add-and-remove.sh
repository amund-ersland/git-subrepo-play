#!/bin/bash
set -eo pipefail

# define constants
LAYERS=3
NUM_USERS=2

# save current pwd for return
_PWD=$PWD

# scenarios live in scenarios/<category>/ — run from the demo root so config.conf
# and the output_dir symlink resolve there, and source utils from scenarios/utils
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

# parse args and utils
for u in scenarios/utils/*; do source $u; done
parse_args "$@"

# start script
TITLE "This script shows the gotcha of REMOVING a submodule. We build a 3-layer hierarchy (parent-repo → child-repo → grandchild-repo). user1 removes grandchild-repo from child-repo the proper way (deinit + git rm), bumps parent-repo to record the new child-repo, and pushes everything. Then user2 simply pulls and runs 'submodule update --init --recursive'. The surprise: git updates the pointers and drops grandchild-repo from .gitmodules, but it does NOT delete grandchild-repo's directory from user2's disk — git refuses to remove a submodule working tree on checkout, so a STALE grandchild-repo folder is left behind."

prefix="$(basename "$0" | cut -d _ -f 1)"
STEP "Set up repos in $LAYERS layers (parent-repo → child-repo → grandchild-repo) and clone it for user2"
create_submodule_hierarchy $prefix $LAYERS

# Remember what user2 has on disk BEFORE user1 removes anything.
user2_gc_dir="$root_dir/user2/parent-repo/child-repo/grandchild-repo"
user2_child_before=$(current_sha "$root_dir/user2/parent-repo/child-repo")

STEP "user1 removes grandchild-repo from child-repo (deinit + git rm) and pushes child-repo"
remove_submodule "$root_dir/user1/parent-repo/child-repo" grandchild-repo

STEP "user1 records the new child-repo (without grandchild-repo) in parent-repo and pushes"
update_superproject_with_submodule "$root_dir/user1/parent-repo" child-repo \
    "Update child-repo pointer after removing grandchild-repo"

STEP "user2 pulls and runs 'submodule update --init --recursive' to get the team's changes"
update_submodules $root_dir/user2/parent-repo --init

STEP "Look at what user2 has on disk now — grandchild-repo is no longer a submodule, but is the directory gone?"
STDOUT_INFO "👤 User 2 parent-repo tree after the update:"
tree "$root_dir/user2/parent-repo"

STEP "Print status for user 1 and 2 for the repos"
print_repo_status $root_dir/user1/parent-repo child-repo user1
print_repo_status $root_dir/user2/parent-repo child-repo user2

STEP "🧪 Run tests"

INFO "🧪 TEST: child-repo of user1 vs user2 → should be EQUAL. user1 removed grandchild-repo, committed child-repo, bumped the parent pointer; user2's plain (non --remote) update checks out that exact recorded child-repo commit."
assert_sha_equal "$root_dir/user1/parent-repo/child-repo" "$root_dir/user2/parent-repo/child-repo"

INFO "🧪 TEST: user2's child-repo advanced from before → the removal commit really was pulled and checked out, child-repo did not stay put."
assert_sha_advanced "$root_dir/user2/parent-repo/child-repo" "$user2_child_before"

INFO "🧪 TEST: grandchild-repo is gone from user2's .gitmodules → 'git rm' removed the definition and user2 pulled that change."
assert_not_in_gitmodules "$root_dir/user2/parent-repo/child-repo" grandchild-repo

INFO "🧪 TEST: grandchild-repo is gone from user2's RECORDED gitlinks → child-repo's HEAD tree no longer lists it as a submodule."
assert_submodule_matches_gitlink "$root_dir/user2/parent-repo" child-repo

INFO "🧪 TEST (the gotcha): user2's grandchild-repo DIRECTORY still exists on disk → git did NOT auto-remove the stale submodule working tree on checkout, so user2 is left with an orphaned folder they must delete by hand."
assert_path_exists "$user2_gc_dir" "user2's grandchild-repo directory"

INFO "ℹ️  NOTE: For user1 (who ran the removal) the directory IS gone, because 'git submodule deinit -f' wiped its working tree locally before 'git rm'."
assert_path_absent "$root_dir/user1/parent-repo/child-repo/grandchild-repo" "user1's grandchild-repo directory"

INFO "ℹ️  TAKEAWAY: Removing a submodule cleans up only for the person who runs deinit + git rm. Teammates who pull keep the old submodule directory as a stale, no-longer-tracked folder. Tell them to 'git submodule update' AND manually 'rm -rf <old-submodule>' (or 'git clean' it away)."

# return to start folder
cd $_PWD

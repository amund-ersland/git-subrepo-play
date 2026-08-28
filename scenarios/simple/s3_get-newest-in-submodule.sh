#!/bin/bash
set -eo pipefail

# define constants
LAYERS=3

# save current pwd for return
_PWD=$PWD

# scenarios live in scenarios/<category>/ — run from the demo root so config.conf
# and the output_dir symlink resolve there, and source utils from scenarios/utils
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

# parse args and utils
for u in scenarios/utils/*; do source $u; done
parse_args "$@"

# start script
TITLE "This script demonstrates updating submodules recursively with the remote flag to get the newest commit of the submodule"

prefix="$(basename "$0" | cut -d _ -f 1)"
STEP "Set up repos in $LAYERS layers"
create_submodule_hierarchy $prefix $LAYERS

STEP "user1 adds a file to grandchild-repo"
add_random_file_and_push "$root_dir/user1/parent-repo/child-repo/grandchild-repo"

STEP "user1 adds a file to child-repo"
add_random_file_and_push "$root_dir/user1/parent-repo/child-repo"

STEP "user2 pulls all the updates fetching the latest remotes"
update_submodules $root_dir/user2/parent-repo --remote

STEP "Print status for user 1 and 2 for the repos"
print_repo_status $root_dir/user1/parent-repo child-repo user1
print_repo_status $root_dir/user2/parent-repo child-repo user2
print_repo_status $root_dir/user1/parent-repo/child-repo grandchild-repo user1
print_repo_status $root_dir/user2/parent-repo/child-repo grandchild-repo user2

STEP "🧪 Run tests"

INFO "🧪 TEST: child-repo of user1 vs user2 → should be EQUAL, because user2 ran 'submodule update --remote --recursive', which fetches and checks out the newest commit on the submodule's remote branch — the same commit user1 just pushed."
assert_sha_equal "$root_dir/user1/parent-repo/child-repo" "$root_dir/user2/parent-repo/child-repo"

INFO "🧪 TEST: grandchild-repo of user1 vs user2 → should be EQUAL, because --remote applies recursively, so the nested grandchild-repo is also advanced to the newest commit on its remote branch that user1 pushed."
assert_sha_equal "$root_dir/user1/parent-repo/child-repo/grandchild-repo" "$root_dir/user2/parent-repo/child-repo/grandchild-repo"

INFO "🧪 TEST: user2's child-repo HEAD == its remote branch tip → --remote fetches and checks out the newest commit on the submodule's tracked remote branch."
assert_submodule_at_remote_tip "$root_dir/user2/parent-repo" child-repo

INFO "🧪 TEST: user2's grandchild-repo HEAD == its remote branch tip → --remote recursed into the nested submodule too."
assert_submodule_at_remote_tip "$root_dir/user2/parent-repo/child-repo" grandchild-repo

INFO "🧪 TEST: user2's child-repo HEAD is AHEAD of the pointer recorded in parent-repo → this is the key difference from a default update: user1 pushed new commits but never bumped the superproject pointer, so --remote moved the working tree past the recorded gitlink."
assert_submodule_differs_gitlink "$root_dir/user2/parent-repo" child-repo

INFO "🧪 TEST: user2's grandchild-repo HEAD is AHEAD of the pointer recorded in child-repo → same --remote behaviour at the nested level."
assert_submodule_differs_gitlink "$root_dir/user2/parent-repo/child-repo" grandchild-repo

cd $_PWD

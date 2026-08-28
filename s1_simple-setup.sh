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
TITLE "This script demonstrate the setup of a nested repo and cloning for a second user"
prefix="$(echo $0 | cut -d _ -f 1 | cut -d / -f 2)"
create_submodule_hierarchy $prefix $LAYERS

PAUSE "🧪 Run tests"

INFO "🧪 TEST: parent-repo of user1 vs user2 → should be EQUAL, because user2 cloned the same parent-repo remote that user1 pushed, so both point at the same superproject commit."
assert_sha_equal "$root_dir/user1/parent-repo" "$root_dir/user2/parent-repo"

INFO "🧪 TEST: child-repo submodule of user1 vs user2 → should be EQUAL, because user2 cloned --recursive and thus checked out the exact submodule commit recorded by the parent-repo."
assert_sha_equal "$root_dir/user1/parent-repo/child-repo" "$root_dir/user2/parent-repo/child-repo"

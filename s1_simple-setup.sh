#!/bin/bash
set -eo pipefail

for u in utils/*; do source $u; done

parse_args "$@"

LAYERS=2
prefix="$(echo $0 | cut -d _ -f 1 | cut -d / -f 2)"
setup_layered_repos $prefix $LAYERS

PAUSE "🧪 Run tests"

INFO "🧪 TEST: parent-repo of user1 vs user2 → should be EQUAL, because user2 cloned the same parent-repo remote that user1 pushed, so both point at the same superproject commit."
sha_is_equal "$root_dir/user1/parent-repo" "$root_dir/user2/parent-repo"

INFO "🧪 TEST: child-repo submodule of user1 vs user2 → should be EQUAL, because user2 cloned --recursive and thus checked out the exact submodule commit recorded by the parent-repo."
sha_is_equal "$root_dir/user1/parent-repo/child-repo" "$root_dir/user2/parent-repo/child-repo"

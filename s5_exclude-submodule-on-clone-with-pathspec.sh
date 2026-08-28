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
TITLE "This script demonstrates the ONE reliable way to make a colleague NOT get a submodule: clone with a pathspec (git clone --recurse-submodules=':(exclude)child-repo-2'). The excluded submodule is written to submodule.active in the clone's LOCAL config, so it stays inactive and is skipped by later 'submodule update' (without --init)."

STEP "Set up repos in $LAYERS layers with $REPOS_PER_LAYER in each"

prefix="$(echo $0 | cut -d _ -f 1 | cut -d / -f 2)"
create_submodule_hierarchy $prefix $LAYERS $REPOS_PER_LAYER "skip-user2"

STEP "user2 clones and EXCLUDES child-repo-2 via a pathspec, so it is never activated or checked out"
clone_repo $remote_dir/parent-repo $root_dir/user2 --recurse ':(exclude)child-repo-2'

STEP "Show the active flags git wrote into user2's LOCAL config (child-repo-2 excluded => inactive)"
print_submodule_active_flags "$root_dir/user2/parent-repo" "config"

STEP "user1 advances BOTH child repos with a new commit each"
for c in 1 2; do
    add_random_file_and_push "$root_dir/user1/parent-repo/child-repo-$c"
done

STEP "user2 updates submodules to newest remote WITHOUT --init so the excluded submodule stays inactive"
update_submodules $root_dir/user2/parent-repo --remote

STEP "Print status for user 1 and 2 for the repos"
print_repo_statuses $NUM_USERS $REPOS_PER_LAYER

STEP "🧪 Run tests"

INFO "🧪 TEST: child-repo-1 of user1 vs user2 → should be EQUAL. child-repo-1 was inside the active pathspec, so it was cloned and 'submodule update --remote' fetched user1's newest commit."
assert_sha_equal "$root_dir/user1/parent-repo/child-repo-1" "$root_dir/user2/parent-repo/child-repo-1"

INFO "🧪 TEST: child-repo-2 of user1 vs user2 → should NOT be EQUAL. The clone pathspec ':(exclude)child-repo-2' set submodule.active in user2's LOCAL config to exclude it, so it was never checked out and the non-init update skips it — user2 never gets child-repo-2 or its updates."
assert_sha_not_equal "$root_dir/user1/parent-repo/child-repo-2" "$root_dir/user2/parent-repo/child-repo-2"

INFO "🧪 TEST: user2's child-repo-2 is genuinely NOT checked out → no .git link and an empty working tree, which is stronger than a mere SHA difference (that also passes for an empty dir)."
assert_submodule_not_checked_out "$root_dir/user2/parent-repo" child-repo-2

INFO "🧪 TEST: user2's child-repo-1 IS checked out → the included submodule was initialized normally."
assert_submodule_initialized "$root_dir/user2/parent-repo" child-repo-1

INFO "🧪 TEST: child-repo-2 is STILL declared in .gitmodules → the exclusion is purely a local-config decision at clone time; it does not remove the submodule definition."
assert_in_gitmodules "$root_dir/user2/parent-repo" child-repo-2

INFO "ℹ️  NOTE: The exclusion lives in the CLONER's local config (via the pathspec), not in .gitmodules — child-repo-2 is still listed in .gitmodules. See s6 for why setting active=false in .gitmodules does NOT achieve this on a recursive clone."

# return to start folder
cd $_PWD

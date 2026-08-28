#!/bin/bash
set -eo pipefail

# define constants
LAYERS=2
REPOS_PER_LAYER=2
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
TITLE "This script demonstrates the use of inactive flag in local gitconfig to skip updating a repo"

prefix="$(basename "$0" | cut -d _ -f 1)"
STEP "Set up repos in $LAYERS layers with $REPOS_PER_LAYER in each"
create_submodule_hierarchy $prefix $LAYERS $REPOS_PER_LAYER "skip-user2"

STEP "user2 clones the repo recursively so both children start active and checked out"
clone_repo $remote_dir/parent-repo $root_dir/user2 --recursive

STEP "user1 advances both child repos with a new commit each"
for c in 1 2; do
    add_random_file_and_push "$root_dir/user1/parent-repo/child-repo-$c"
done

STEP "user2 sets child-repo-2 to inactive in LOCAL git config (not .gitmodules)"
set_submodule_active $root_dir/user2/parent-repo child-repo-2 inactive config
print_submodule_active_flags "$root_dir/user2/parent-repo" "config"

STEP "user2 updates submodules to newest remote WITHOUT --init so the inactive flag is honored"
user2_child2_before=$(current_sha "$root_dir/user2/parent-repo/child-repo-2")
update_submodules $root_dir/user2/parent-repo --remote

STEP "Print status for user 1 and 2 for the repos"
print_repo_statuses $NUM_USERS $REPOS_PER_LAYER

STEP "🧪 Run tests"

INFO "🧪 TEST: child-repo-1 of user1 vs user2 → should be EQUAL. child-repo-1 stayed active, so 'submodule update --remote --recursive' fetched and checked out the newest commit user1 pushed."
assert_sha_equal "$root_dir/user1/parent-repo/child-repo-1" "$root_dir/user2/parent-repo/child-repo-1"

INFO "🧪 TEST: child-repo-2 of user1 vs user2 → should NOT be EQUAL. user2 set submodule.child-repo-2.active=false in its LOCAL git config, and because the update ran WITHOUT --init, git honors that flag and skips the submodule — so user2's child-repo-2 stays behind while user1's advanced."
assert_sha_not_equal "$root_dir/user1/parent-repo/child-repo-2" "$root_dir/user2/parent-repo/child-repo-2"

INFO "🧪 TEST: the state the outcome depends on → submodule.child-repo-2.active is literally 'false' in user2's LOCAL config."
assert_active_flag "$root_dir/user2/parent-repo" child-repo-2 false config

INFO "🧪 TEST: child-repo-1 has NO active override in local config → it stays active via its url (rule 3) and is therefore updated."
assert_local_active_unset "$root_dir/user2/parent-repo" child-repo-1

INFO "🧪 TEST: user2's child-repo-2 HEAD is UNCHANGED from before the update → it genuinely stayed put (the skip happened), rather than merely differing from user1 for some other reason."
assert_sha_unchanged "$root_dir/user2/parent-repo/child-repo-2" "$user2_child2_before"

cd $_PWD

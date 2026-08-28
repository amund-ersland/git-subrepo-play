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
TITLE "This script demonstrates the use of inactive flag in local gitconfig to skip updating a repo"

prefix="$(echo $0 | cut -d _ -f 1 | cut -d / -f 2)"
STDOUT_PAUSE "Setup repos in $LAYERS with $REPOS_PER_LAYER in each"
setup_layered_repos $prefix $LAYERS $REPOS_PER_LAYER "skip-user2"

PAUSE "user2 clones the repo recursively so both children start active and checked out"
clone_recursive $remote_dir/parent-repo $root_dir/user2

PAUSE "user1 advances both child repos with a new commit each"
for c in 1 2; do
    commit_file "$root_dir/user1/parent-repo/child-repo-$c"
done

PAUSE "user2 sets child-repo-2 to inactive in LOCAL git config (not .gitmodules)"
set_submodule_status $root_dir/user2/parent-repo child-repo-2 inactive config
print_submodule_active_status "$root_dir/user2/parent-repo" "config"

PAUSE "user2 updates submodules to newest remote WITHOUT --init so the inactive flag is honored"
update_remote_recursive_no_init $root_dir/user2/parent-repo
PAUSE "Print status for user 1 and 2 for the repos"

print_repo_statuses $NUM_USERS $REPOS_PER_LAYER

PAUSE "🧪 Run tests"

INFO "🧪 TEST: child-repo-1 of user1 vs user2 → should be EQUAL. child-repo-1 stayed active, so 'submodule update --remote --recursive' fetched and checked out the newest commit user1 pushed."
sha_is_equal "$root_dir/user1/parent-repo/child-repo-1" "$root_dir/user2/parent-repo/child-repo-1"

INFO "🧪 TEST: child-repo-2 of user1 vs user2 → should NOT be EQUAL. user2 set submodule.child-repo-2.active=false in its LOCAL git config, and because the update ran WITHOUT --init, git honors that flag and skips the submodule — so user2's child-repo-2 stays behind while user1's advanced."
sha_is_not_equal "$root_dir/user1/parent-repo/child-repo-2" "$root_dir/user2/parent-repo/child-repo-2"

cd $_PWD

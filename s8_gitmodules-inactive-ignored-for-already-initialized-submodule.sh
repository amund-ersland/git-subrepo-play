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
TITLE "This script shows that pushing active=false in .gitmodules does NOT retroactively deactivate a submodule a colleague has ALREADY initialized. user2 cloned recursively (so child-repo-2 has a url in local config), then user1 pushes active=false in .gitmodules. Even with a plain 'submodule update --remote' (no --init), git still updates child-repo-2, because a set url (active rule 3) keeps it active and the .gitmodules active flag is not consulted for initialized submodules. Contrast with s5, where the flag lives in LOCAL config and IS honored."

STEP "Set up repos in $LAYERS layers with $REPOS_PER_LAYER in each (user2 clones recursively up front, so both children start initialized with a url in local config)"

prefix="$(echo $0 | cut -d _ -f 1 | cut -d / -f 2)"
create_submodule_hierarchy $prefix $LAYERS $REPOS_PER_LAYER

STEP "user1 sets child-repo-2 to inactive in .gitmodules and pushes it to the team"
set_submodule_active "$root_dir/user1/parent-repo" child-repo-2 inactive
print_submodule_active_flags "$root_dir/user1/parent-repo"
commit_push_gitmodules "$root_dir/user1/parent-repo"

STEP "user1 advances BOTH child repos with a new commit each"
for c in 1 2; do
    add_random_file_and_push "$root_dir/user1/parent-repo/child-repo-$c"
done

STEP "user2 updates submodules to newest remote WITHOUT --init, expecting the .gitmodules flag to protect child-repo-2"
update_submodules $root_dir/user2/parent-repo --remote

STEP "Show that user2 still has child-repo-2 active in LOCAL config (url set) — .gitmodules active=false never landed here"
print_submodule_active_flags "$root_dir/user2/parent-repo" "gitmodules"
STDOUT_INFO "local submodule config (note child-repo-2.url is present => active by rule 3):"
TEXT "$(cd $root_dir/user2/parent-repo && git config --local --get-regexp '^submodule\.')"

STEP "Print status for user 1 and 2 for the repos"
print_repo_statuses $NUM_USERS $REPOS_PER_LAYER

STEP "🧪 Run tests"

INFO "🧪 TEST: child-repo-1 of user1 vs user2 → should be EQUAL. child-repo-1 stayed active, so 'submodule update --remote' fetched and checked out the newest commit user1 pushed."
assert_sha_equal "$root_dir/user1/parent-repo/child-repo-1" "$root_dir/user2/parent-repo/child-repo-1"

INFO "🧪 TEST: child-repo-2 of user1 vs user2 → should be EQUAL even though .gitmodules says active=false. Because user2 already initialized child-repo-2 (its url is in local config), git's active check returns true at rule (3) 'url is set'. The active=false in .gitmodules is NOT copied into local config and is not consulted for an initialized submodule, so the non-init update updates it anyway."
assert_sha_equal "$root_dir/user1/parent-repo/child-repo-2" "$root_dir/user2/parent-repo/child-repo-2"

INFO "ℹ️  NOTE: So you CANNOT retroactively stop a teammate from getting a submodule by pushing active=false in .gitmodules once they've initialized it. To deactivate it you must set active=false in THEIR local config (see s5, where rule (1) submodule.<name>.active=false overrides the url), or have them exclude it at clone time with a pathspec (see s6)."

# return to start folder
cd $_PWD

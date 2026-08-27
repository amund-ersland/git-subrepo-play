#!/bin/bash
set -eo pipefail

_PWD=$PWD

for u in utils/*; do
    source $u
done

TITLE "This script demonstrates that submodule.<name>.active=false is honored by auto commands (no --init) but overridden by --init"

LAYERS=2
REPOS_PER_LAYER=2
prefix="$(echo $0 | cut -d _ -f 1 | cut -d / -f 2)"
STDOUT_PAUSE "Setup repos in $LAYERS layers with $REPOS_PER_LAYER in each. user2 clones recursively so both submodules start initialized"
setup_layered_repos $prefix $LAYERS $REPOS_PER_LAYER

superproject="$root_dir/user1/parent-repo"

PAUSE "user1 pushes a NEW commit into child-repo-1 and child-repo-2 (advances the child remotes)"
for c in 1 2; do
    commit_file "$superproject/child-repo-$c"
done

PAUSE "user2 marks child-repo-2 INACTIVE in its LOCAL git config"
set_submodule_status "$root_dir/user2/parent-repo" child-repo-2 inactive config
print_submodule_active_status "$root_dir/user2/parent-repo" config

PAUSE "PART A: user2 updates WITHOUT --init -> active flag is honored, child-repo-2 is skipped"
update_remote_recursive_no_init $root_dir/user2/parent-repo

print_repo_statuses $LAYERS $REPOS_PER_LAYER

PAUSE "PART B: user2 updates WITH --init -> --init re-activates child-repo-2 and updates it"
update_remote_recursive $root_dir/user2/parent-repo
print_submodule_active_status "$root_dir/user2/parent-repo" config

print_repo_statuses $LAYERS $REPOS_PER_LAYER

cd $_PWD

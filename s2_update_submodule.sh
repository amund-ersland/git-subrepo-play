#!/bin/bash
set -eo pipefail

source utils/common.sh
source utils/s2.sh

s2_init

CASE_START "user1 updates child-repo"

INFO "# User 1 performs a commit"
make_commit "$root_dir/user1/parent-repo/child-repo" "user1 add file"

INFO "# User 1 updates parent repo with newest child repo"
update_superproject_with_submodule $root_dir/user1/parent-repo $root_dir/user1/parent-repo/child-repo

INFO "# User 2 pulls all the updates"
update_recursive $root_dir/user2/parent-repo

make_pretty_logs

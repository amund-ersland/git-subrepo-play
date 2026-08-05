#!/bin/bash
set -eo pipefail

_PWD=$PWD

source utils/common.sh

setup_layered_repos 3 "s2"

CASE_START "user1 updates child-repo"

INFO "# user1 performs a commit to child repo"
make_commit "$root_dir/user1/parent-repo/child-repo"

INFO "# user1 updates parent repo with newest child repo"
update_superproject_with_submodule $root_dir/user1/parent-repo child-repo

INFO "# user2 pulls all the updates"
update_init_recursive $root_dir/user2/parent-repo

repo_status $root_dir/user1/parent-repo child-repo user1
repo_status $root_dir/user2/parent-repo child-repo user2

cd $_PWD

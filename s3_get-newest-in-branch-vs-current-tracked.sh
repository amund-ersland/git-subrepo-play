#!/bin/bash
set -eo pipefail

_PWD=$PWD

source utils/common.sh

setup_layered_repos 2 "s3"

CASE_START "user1 updates child-repo"

INFO "# user1 performs a commit to child repo"
make_commit "$root_dir/user1/parent-repo/child-repo"

INFO "# user2 pulls all the updates"
update_recursive $root_dir/user2/parent-repo

repo_status $root_dir/user1/parent-repo child-repo user1
repo_status $root_dir/user2/parent-repo child-repo user2

cd $_PWD

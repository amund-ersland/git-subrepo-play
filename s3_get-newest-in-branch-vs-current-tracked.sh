#!/bin/bash
set -eo pipefail

_PWD=$PWD

source utils/common.sh

LAYERS=3
STDOUT_PAUSE "Setup repos in $LAYERS layers"
setup_layered_repos $LAYERS "s3"

PAUSE "user1 performs a commit to grandchild-repo"
make_commit "$root_dir/user1/parent-repo/child-repo/grandchild-repo"

PAUSE "user1 performs a commit to child-repo"
make_commit "$root_dir/user1/parent-repo/child-repo"

PAUSE "user2 pulls all the updates fetching the latest remotes"
update_remote_recursive $root_dir/user2/parent-repo

PAUSE "Print status for user1"
repo_status $root_dir/user1/parent-repo child-repo user1
PAUSE "Print status for user2"
repo_status $root_dir/user2/parent-repo child-repo user2

cd $_PWD

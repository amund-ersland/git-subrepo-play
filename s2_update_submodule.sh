#!/bin/bash
set -eo pipefail

source utils/common.sh
source utils/s2.sh

s2_init

#CASE_START "user1 updates child-repo and updates parent parent to point to the new commit"
#
#INFO "# User 1 performs a commit and pushes to remote"
#make_commit_and_push "$root_dir/user1/parent-repo/child-repo" "user1 add file"



make_pretty_logs

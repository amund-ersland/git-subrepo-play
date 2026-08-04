#!/bin/bash
set -eo pipefail

source utils/common.sh
source utils/s2.sh

s2_init

CASE_START "user1 update makes a commit to child-repo"

PRINT_INFO "-> commit and push file to child-repo"
make_commit_and_push "$root_dir/user1/parent-repo/child-repo" "user1 add file"

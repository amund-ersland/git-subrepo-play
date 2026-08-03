#!/bin/bash
set -eo pipefail

source utils/common.sh
source utils/s1.sh

create_output_root_dir "s1_simple-setup"

create_bare_repo "main-repo"
create_bare_repo "sub-repo"

#==============================================================================
PRINT_LINE
PRINT_INFO "Setup main and subrepo from user 1 and a file in each"
PRINT_LINE

PRINT_INFO "User1 clones main-repo and adds a file"
user_clone_repo $origins_dir/main-repo $root_dir/user1
add_file_to_repo $root_dir/user1/main-repo
git -C $root_dir/user1/main-repo push

PRINT_INFO "User1 clones sub-repo and adds a file"
user_clone_repo $origins_dir/sub-repo $root_dir/user1
add_file_to_repo $root_dir/user1/sub-repo
git -C $root_dir/user1/sub-repo push

#==============================================================================
PRINT_LINE
PRINT_INFO "User 1 adds sub-repo as a sub repo of main-repo"
PRINT_LINE

add_repo_as_submodule "$origins_dir/sub-repo" "$root_dir/user1/main-repo"

PRINT_INFO "Delete flat sub-repo as it is contained within main-repo"
rm -rf $root_dir/user1/sub-repo

#==============================================================================
PRINT_LINE
PRINT_INFO "User 2 clones main-repo recursively and gets sub-repo as part of it"
PRINT_LINE

user_clone_recursive $origins_dir/main-repo $root_dir/user2
PRINT_INFO "git log for user2"
tree "$root_dir/user2/main-repo"

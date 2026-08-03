#!/bin/bash
set -eo pipefail

source utils/common.sh

# sets up the repos in the same way as s1
# Both users have now a copy of the repos where sub-repo is a submodule of main-repo
s2_init() {
    create_output_root_dir "s2_update-submodule"

    create_bare_repo "main-repo"
    create_bare_repo "sub-repo"

    user_clone_repo $origins_dir/main-repo $root_dir/user1
    add_file_to_repo $root_dir/user1/main-repo
    git -C $root_dir/user1/main-repo push

    user_clone_repo $origins_dir/sub-repo $root_dir/user1
    add_file_to_repo $root_dir/user1/sub-repo
    git -C $root_dir/user1/sub-repo push

    add_repo_as_submodule "$origins_dir/sub-repo" "$root_dir/user1/main-repo"

    rm -rf $root_dir/user1/sub-repo

    user_clone_recursive $origins_dir/main-repo $root_dir/user2
    tree "$root_dir/user2/main-repo"
}

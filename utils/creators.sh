setup_layered_repos(){
    local levels=$1
    local name_base=${2:-""}
    create_output_root_dir $name_base

    if [[ $levels -eq 2 ]]; then
        create_bare_repo "parent-repo"
        create_bare_repo "child-repo"

        # Setup user1 parent"
        clone $remote_dir/parent-repo $root_dir/user1
        make_commit $root_dir/user1/parent-repo

        # Setup user1 child initial commit (footnote 1)"
        clone $remote_dir/child-repo $root_dir/user1
        make_commit $root_dir/user1/child-repo
        run rm -rf $root_dir/user1/child-repo

        add_repo_as_submodule \
            --superproject "$root_dir/user1/parent-repo" \
            --child_remote "$remote_dir/child-repo"

        clone_recursive $remote_dir/parent-repo $root_dir/user2

    elif [[ $levels -eq 3 ]]; then
        create_bare_repo "parent-repo"
        create_bare_repo "child-repo"
        create_bare_repo "grandchild-repo"

        # Setup user1 parent"
        clone $remote_dir/parent-repo $root_dir/user1
        make_commit $root_dir/user1/parent-repo

        # Setup user1 child initial commit (footnote 1)"
        clone $remote_dir/child-repo $root_dir/user1
        make_commit $root_dir/user1/child-repo
        run rm -rf $root_dir/user1/child-repo

        # Setup user1 grandchild initial commit"
        clone $remote_dir/grandchild-repo $root_dir/user1
        make_commit $root_dir/user1/grandchild-repo
        run rm -rf $root_dir/user1/grandchild-repo

        add_repo_as_submodule \
            --superproject "$root_dir/user1/parent-repo" \
            --child_remote "$remote_dir/child-repo"

        add_repo_as_submodule \
            --superproject "$root_dir/user1/parent-repo/child-repo" \
            --child_remote "$remote_dir/grandchild-repo"

        # Update parent repo to record child-repo's new commit (which now contains the grandchild submodule)
        update_superproject_with_submodule \
            "$root_dir/user1/parent-repo" \
            "child-repo" \
            "Update child submodule to include grandchild-repo"

        clone_recursive $remote_dir/parent-repo $root_dir/user2
    fi

    echo -e  "\033[32m ✅ Setup complete\033[0m"

    STDOUT_INFO $LINE
    STDOUT_INFO "📁 Remote repositories structure:"
    tree -L 1 "$remote_dir"

    echo -e ""
    STDOUT_INFO $LINE
    STDOUT_INFO "👤 User 1 workspace structure:"
    tree "$root_dir/user1"

    echo -e ""
    STDOUT_INFO $LINE
    STDOUT_INFO "👤 User 2 workspace structure:"
    tree "$root_dir/user2"
}

#===============================================================================
create_output_root_dir() {
    source config.conf

    local name_base="$1"
    name="${name_base}_$(date "$CONF_TIMESTAMP_FORMAT")"

    # root for remote repos
    root_dir="$CONF_OUTPUT_DIR/$name"
    remote_dir="$root_dir/remotes"
    mkdir -p $remote_dir

    # user workspaces
    mkdir -p "$root_dir/user1"
    mkdir -p "$root_dir/user2"

    # create symlink from current dir
    if [[ -L output_dir ]]; then
        rm -rf output_dir
    fi

    # create log dir
    mkdir $root_dir/logs
    CMD_LOG=$root_dir/logs/commands.log
    FULL_LOG=$root_dir/logs/full.log

    ln -s $root_dir output_dir
}

#===============================================================================
create_bare_repo() {
    local name="$1"
    ensure_dir $remote_dir
    run git init --bare $name
}

#===============================================================================
# Footnotes

# 1) Make initial commit to child repo to be able to add it as a submodule

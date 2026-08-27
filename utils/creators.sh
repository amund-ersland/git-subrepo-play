setup_layered_repos(){
    local levels=$1
    local repos_per_layer=${2:-1}
    local name_base=${3:-""}
    create_output_root_dir $name_base

    create_bare_repo "parent-repo"
    for i in $(seq 1 $repos_per_layer); do
        create_bare_repo "child-repo-$i"
    done

    # Setup user1 parent
    clone $remote_dir/parent-repo $root_dir/user1
    make_commit $root_dir/user1/parent-repo

    # Setup each child with initial commit (footnote 1)
    for i in $(seq 1 $repos_per_layer); do
        clone $remote_dir/child-repo-$i $root_dir/user1
        make_commit $root_dir/user1/child-repo-$i
        run rm -rf $root_dir/user1/child-repo-$i
    done

    if [[ $levels -ge 3 ]]; then
        # Setup each grandchild with initial commit
        for i in $(seq 1 $repos_per_layer); do
            for j in $(seq 1 $repos_per_layer); do
                create_bare_repo "grandchild-repo-$i-$j"
                clone $remote_dir/grandchild-repo-$i-$j $root_dir/user1
                make_commit $root_dir/user1/grandchild-repo-$i-$j
                run rm -rf $root_dir/user1/grandchild-repo-$i-$j
            done
        done
    fi

    # Add child repos as submodules to parent
    for i in $(seq 1 $repos_per_layer); do
        add_repo_as_submodule \
            --superproject "$root_dir/user1/parent-repo" \
            --child_remote "$remote_dir/child-repo-$i"
    done

    if [[ $levels -ge 3 ]]; then
        # Add grandchild repos as submodules to each child
        for i in $(seq 1 $repos_per_layer); do
            for j in $(seq 1 $repos_per_layer); do
                add_repo_as_submodule \
                    --superproject "$root_dir/user1/parent-repo/child-repo-$i" \
                    --child_remote "$remote_dir/grandchild-repo-$i-$j"
            done
        done

        # Update parent to record each child's new commit (now containing grandchild submodules)
        for i in $(seq 1 $repos_per_layer); do
            update_superproject_with_submodule \
                "$root_dir/user1/parent-repo" \
                "child-repo-$i" \
                "Update child-repo-$i submodule to include grandchild submodules"
        done
    fi

    clone_recursive $remote_dir/parent-repo $root_dir/user2

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

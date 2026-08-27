setup_layered_repos(){
    local name_base=${1:-""}
    local layers=$2
    local repos_per_layer=${3:-1}
    local extra=$4

    create_output_root_dir $name_base

    create_bare_repo "parent-repo"
    if [[ $repos_per_layer -eq 1 ]]; then
        create_bare_repo "child-repo"
    else
        for i in $(seq 1 $repos_per_layer); do
            create_bare_repo "child-repo-$i"
        done
    fi

    # Setup user1 parent
    clone $remote_dir/parent-repo $root_dir/user1
    commit_file $root_dir/user1/parent-repo

    # Setup each child with initial commit (footnote 1)
    if [[ $repos_per_layer -eq 1 ]]; then
        clone $remote_dir/child-repo $root_dir/user1
        commit_file $root_dir/user1/child-repo
        run rm -rf $root_dir/user1/child-repo
    else
        for i in $(seq 1 $repos_per_layer); do
            clone $remote_dir/child-repo-$i $root_dir/user1
            commit_file $root_dir/user1/child-repo-$i
            run rm -rf $root_dir/user1/child-repo-$i
        done
    fi

    if [[ $layers -ge 3 ]]; then
        # Setup each grandchild with initial commit
        if [[ $repos_per_layer -eq 1 ]]; then
            create_bare_repo "grandchild-repo"
            clone $remote_dir/grandchild-repo $root_dir/user1
            commit_file $root_dir/user1/grandchild-repo
            run rm -rf $root_dir/user1/grandchild-repo
        else
            for i in $(seq 1 $repos_per_layer); do
                for j in $(seq 1 $repos_per_layer); do
                    create_bare_repo "grandchild-repo-$i-$j"
                    clone $remote_dir/grandchild-repo-$i-$j $root_dir/user1
                    commit_file $root_dir/user1/grandchild-repo-$i-$j
                    run rm -rf $root_dir/user1/grandchild-repo-$i-$j
                done
            done
        fi
    fi

    # Add child repos as submodules to parent
    if [[ $repos_per_layer -eq 1 ]]; then
        add_repo_as_submodule \
            --superproject "$root_dir/user1/parent-repo" \
            --child_remote "$remote_dir/child-repo"
    else
        for i in $(seq 1 $repos_per_layer); do
            add_repo_as_submodule \
                --superproject "$root_dir/user1/parent-repo" \
                --child_remote "$remote_dir/child-repo-$i"
        done
    fi

    if [[ $layers -ge 3 ]]; then
        # Add grandchild repos as submodules to each child
        if [[ $repos_per_layer -eq 1 ]]; then
            add_repo_as_submodule \
                --superproject "$root_dir/user1/parent-repo/child-repo" \
                --child_remote "$remote_dir/grandchild-repo"
        else
            for i in $(seq 1 $repos_per_layer); do
                for j in $(seq 1 $repos_per_layer); do
                    add_repo_as_submodule \
                        --superproject "$root_dir/user1/parent-repo/child-repo-$i" \
                        --child_remote "$remote_dir/grandchild-repo-$i-$j"
                done
            done
        fi

        # Update parent to record each child's new commit (now containing grandchild submodules)
        if [[ $repos_per_layer -eq 1 ]]; then
            update_superproject_with_submodule \
                "$root_dir/user1/parent-repo" \
                "child-repo" \
                "Update child-repo submodule to include grandchild submodules"
        else
            for i in $(seq 1 $repos_per_layer); do
                update_superproject_with_submodule \
                    "$root_dir/user1/parent-repo" \
                    "child-repo-$i" \
                    "Update child-repo-$i submodule to include grandchild submodules"
            done
        fi
    fi

    if [[ $extra != "skip-user2" ]]; then
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

    if [[ $extra != "skip-user2" ]]; then
        echo -e ""
        STDOUT_INFO $LINE
        STDOUT_INFO "👤 User 2 workspace structure:"
        tree "$root_dir/user2"
    fi
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

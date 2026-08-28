# Print the submodule names for a layer: "child-repo" for a single repo, or
# "child-repo-1 child-repo-2 ..." when there is more than one per layer.
repo_names(){
    local base=$1 count=$2
    if [[ $count -eq 1 ]]; then
        echo "$base"
    else
        for i in $(seq 1 $count); do echo "$base-$i"; done
    fi
}

# Give a repo its first commit so it can be added as a submodule (footnote 1),
# then remove the throwaway clone.
seed_remote_repo(){
    local name=$1
    create_bare_repo "$name"
    clone_repo $remote_dir/$name $root_dir/user1
    add_random_file_and_push $root_dir/user1/$name
    run rm -rf $root_dir/user1/$name
}

create_submodule_hierarchy(){
    local name_base=${1:-""}
    local layers=$2
    local repos_per_layer=${3:-1}
    local extra=$4

    setup_output_dirs $name_base

    local children=($(repo_names "child-repo" "$repos_per_layer"))

    SECTION "create the parent repo and seed it with a first commit"
    # user1 gets the parent and seeds it with a first commit
    create_bare_repo "parent-repo"
    clone_repo $remote_dir/parent-repo $root_dir/user1
    add_random_file_and_push $root_dir/user1/parent-repo

    SECTION "add each child as a submodule of the parent"
    # Each child needs an initial commit, then is added as a submodule of parent
    for c in "${children[@]}"; do
        seed_remote_repo "$c"
        add_repo_as_submodule \
            --superproject "$root_dir/user1/parent-repo" \
            --child_remote "$remote_dir/$c"
    done

    # Third layer: one grandchild submodule under each child (used by s3).
    if [[ $layers -ge 3 ]]; then
        SECTION "add a grandchild submodule under each child"
        for c in "${children[@]}"; do
            local gc="grandchild-repo"
            [[ ${#children[@]} -gt 1 ]] && gc="grandchild-repo-${c##*-}"

            seed_remote_repo "$gc"
            add_repo_as_submodule \
                --superproject "$root_dir/user1/parent-repo/$c" \
                --child_remote "$remote_dir/$gc"

            # record the child's new commit (it now contains the grandchild)
            update_superproject_with_submodule \
                "$root_dir/user1/parent-repo" "$c" \
                "Update $c submodule to include grandchild submodule"
        done
    fi

    if [[ $extra != "skip-user2" ]]; then
        SECTION "clone the whole hierarchy as user2"
        clone_repo $remote_dir/parent-repo $root_dir/user2 --recursive
    fi

    echo -e  "\033[32m ✅ Setup complete\033[0m"

    SECTION "print the resulting directory structures"
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
setup_output_dirs() {
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
    cd_into $remote_dir
    run git init --bare $name
}

#===============================================================================
# Footnotes

# 1) Make initial commit to child repo to be able to add it as a submodule

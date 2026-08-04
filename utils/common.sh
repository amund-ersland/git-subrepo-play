setup_layered_repos(){
    local levels=$1
    local name_base=${2:-""}
    create_output_root_dir $name_base

    if [[ $levels -eq 2 ]]; then
        create_bare_repo "parent-repo"
        create_bare_repo "child-repo"

        # Setup user1 parent"
        clone $remote_dir/parent-repo $root_dir/user1
        make_commit_and_push $root_dir/user1/parent-repo

        # Setup user1 child initial commit (footnote 1)"
        clone $remote_dir/child-repo $root_dir/user1
        make_commit_and_push $root_dir/user1/child-repo
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
        make_commit_and_push $root_dir/user1/parent-repo

        # Setup user1 child initial commit (footnote 1)"
        clone $remote_dir/child-repo $root_dir/user1
        make_commit_and_push $root_dir/user1/child-repo
        run rm -rf $root_dir/user1/child-repo

        # Setup user1 grandchild initial commit"
        clone $remote_dir/grandchild-repo $root_dir/user1
        make_commit_and_push $root_dir/user1/grandchild-repo
        run rm -rf $root_dir/user1/grandchild-repo

        add_repo_as_submodule \
            --superproject "$root_dir/user1/parent-repo" \
            --child_remote "$remote_dir/child-repo"

        add_repo_as_submodule \
            --superproject "$root_dir/user1/parent-repo/child-repo" \
            --child_remote "$remote_dir/grandchild-repo"

        # Update parent repo to record child-repo's new commit (which now contains the grandchild submodule)
        run git -C "$root_dir/user1/parent-repo" add child-repo
        run git -C "$root_dir/user1/parent-repo" commit -m "Update child submodule to include grandchild-repo"
        run git -C "$root_dir/user1/parent-repo" -c protocol.file.allow=always push

        clone_recursive $remote_dir/parent-repo $root_dir/user2
    fi

    echo -e  "\033[32m ✅ Setup complete\033[0m"

    PRINT_LINE
    PRINT_INFO "📁 Remote repositories structure:"
    tree -L 1 "$remote_dir"

    echo -e ""
    PRINT_LINE
    PRINT_INFO "👤 User 1 workspace structure:"
    tree "$root_dir/user1"

    echo -e ""
    PRINT_LINE
    PRINT_INFO "👤 User 2 workspace structure:"
    tree "$root_dir/user2"
}

CASE_START(){
    local msg=$1
    PRINT_INFO "🚀 $msg"
    read
}

#===============================================================================
# helpers
#===============================================================================

run() {
    echo "$*" >> "$CMD_LOG"
    {
        echo
        echo "$ $*"

        "$@"
        rc=$?

        echo "[exit code: $rc]"
    } >> "$FULL_LOG" 2>&1

    return $rc
}


create_output_root_dir() {
    local name_base="$1"
    name="${name_base}_$(date +%Y-%m-%d_%H:%M:%S)"

    # root for remote repos
    root_dir="/home/amund.ersland/git-play-output/$name"
    remote_dir="$root_dir/remotes"

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

create_bare_repo() {
    local name="$1"
    run git init --bare "$remote_dir/$name"
}

make_commit(){
    local repo_path=$1
    local msg=${2:-""}

    local dir=$repo_path/files

    if [[ ! -d $dir ]]; then
        run mkdir -p $dir
    fi

    local file="$dir/$(uuidgen | md5sum | cut -c1-4).txt"
    last_added=$(basename $file)
    echo "herp derp" > $file
    run git -C $repo_path add $file
    run git -C $repo_path commit -m "$msg, added $last_added to ./files"
}

make_commit_and_push() {
    make_commit $1 $2
    run git -C $1 push
}

clone(){
    local remote_path=$1
    local local_path=$2
    run git clone $remote_path "$local_path/$(basename $remote_path)"
}

clone_recursive(){
    local remote_path=$1
    local local_path=$2
    run git -c protocol.file.allow=always clone --recursive $remote_path "$local_path/$(basename $remote_path)"
}

add_repo_as_submodule(){
    local superproject=""
    local child_remote=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --superproject)
                superproject=$2
                shift 2
                ;;
            --child_remote)
                child_remote=$2
                shift 2
                ;;
            *)
                echo -e "\033[31munknown argument $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$child_remote" || -z "$superproject" ]]; then
        echo -e "\033[31mMissing required arguments: --superproject and/or --child_remote"
        return 1
    fi

    local path_to_submodule=$(basename "$child_remote")

    LOG_HEADER "add $(basename $child_remote) as submodule to $(basename $superproject)"


    run git -C "$superproject" -c protocol.file.allow=always submodule add "$child_remote" "$path_to_submodule"
    run git -C "$superproject" commit -m "Add submodule "$path_to_submodule""

    run git -C "$superproject" -c "protocol.file.allow=always" push
}

LOG_HEADER(){
    echo -e "\n\033[36m$1\033[0m" >> $CMD_LOG
    echo -e "\n\033[36m$1\033[0m" >> $FULL_LOG
}

PRINT_INFO(){
    echo -e "\033[35m$1\033[0m"
}

PRINT_LINE(){
    printf '\033[35m'
    for i in $(seq 1 80); do printf '='; done
    printf '\033[0m\n'
}


#===============================================================================
# Footnotes

# 1) Make initial commit to child repo to be able to add it as a submodule

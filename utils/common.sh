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

    STDOUT_LINE
    STDOUT_INFO "📁 Remote repositories structure:"
    tree -L 1 "$remote_dir"

    echo -e ""
    STDOUT_LINE
    STDOUT_INFO "👤 User 1 workspace structure:"
    tree "$root_dir/user1"

    echo -e ""
    STDOUT_LINE
    STDOUT_INFO "👤 User 2 workspace structure:"
    tree "$root_dir/user2"
}

create_output_root_dir() {
    local name_base="$1"
    name="${name_base}_$(date +%Y-%m-%d_%H:%M:%S)"

    # root for remote repos
    root_dir="/home/amund.ersland/git-play-output/$name"
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
# helpers
#===============================================================================

run() {
    echo "$*" | tee -a "$CMD_LOG"
    {
        echo
        echo "$ $*"

        "$@"
        rc=$?

        if [[ $rc -ne 0 ]]; then
            echo "[exit code: $rc]"
        fi

    } >> "$FULL_LOG" 2>&1

    return $rc
}

create_bare_repo() {
    local name="$1"
    ensure_dir $remote_dir
    run git init --bare $name
}

ensure_dir(){
    dir=$1
    if [[ $(realpath $dir) != "$PWD" ]]; then
        run cd $(relpath $dir)
    fi
}

make_commit(){
    local repo_path=$1
    repo_path=$(relpath $repo_path)
    local msg=${2:-""}

    ensure_dir $repo_path
    local dir=files

    if [[ ! -d $dir ]]; then
        run mkdir -p $dir
    fi

    local file="$dir/$(uuidgen | md5sum | cut -c1-4).txt"
    last_added=$(basename $file)
    echo "herp derp" > $file
    run git add $file
    run git commit -m "\"${msg}add $last_added\""

    run git push
}

relpath(){
    export abs_path=$1
    echo "$(realpath --relative-to $PWD $abs_path)"
}

update_superproject_with_submodule(){
    superproject=$1
    submodule=$2

    local msg="update $(basename $superproject) with current $submodule"
    LOG_INFO "## $msg"

    ensure_dir $superproject
    run git add $submodule
    run git commit -m "$msg"
    run git -c protocol.file.allow=always push
}

clone(){
    local remote_path=$1
    local local_path=$2
    ensure_dir $local_path
    remote_path=$(realpath $remote_path)
    local_path=$(realpath $local_path)

    run git clone $remote_path
}

clone_recursive(){
    local remote_path=$1
    local local_path=$2
    ensure_dir $local_path
    remote_path=$(realpath $remote_path)
    local_path=$(realpath $local_path)

    run git -c protocol.file.allow=always clone --recursive $remote_path
}

update_recursive(){
    local repo=$(relpath $1)
    LOG_INFO "## pull changes in superproject and update submodules in $repo"
    ensure_dir $repo
    run git pull
    run git -c protocol.file.allow=always submodule update --init --recursive
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

    LOG_INFO "## add $(basename $child_remote) as submodule to $(basename $superproject)"

    superproject=$(relpath $superproject)
    run cd $superproject
    run git -c protocol.file.allow=always submodule add "$child_remote" "$path_to_submodule"
    run git commit -m "Add submodule "$path_to_submodule""

    run git -c "protocol.file.allow=always" push
}

repo_status() {
    local superproject=$1
    local submodule=$2

    ensure_dir $superproject

    declare -A what_to_command=(
        [superproject-sha]="git rev-parse --short HEAD"
        [submodule-tracked-sha]="git ls-tree HEAD $submodule | cut -d' ' -f3 | cut -c1-7"
        [submodule-current-sha]="git rev-parse --short HEAD $submodule"
    )

    STDOUT_LINE
    for what in "${!what_to_command[@]}"; do
        echo -e "$what | $(eval ${what_to_command[$what]}) | ${what_to_command[$what]}"
    done

}

INFO(){
    LOG_INFO "$1"
    STDOUT_INFO "$1"
}

LOG_INFO(){
    echo -e "\n\033[35m$1\033[0m" >> $CMD_LOG
    echo -e "\n\033[35m$1\033[0m" >> $FULL_LOG
}

STDOUT_INFO(){
    echo -e "\033[35m$1\033[0m"
}

STDOUT_LINE(){
    printf '\033[35m'
    for i in $(seq 1 80); do printf '='; done
    printf '\033[0m\n'
}

CASE_START(){
    local msg=$1
    INFO "🚀 $msg"
    read
}

#===============================================================================
# Footnotes

# 1) Make initial commit to child repo to be able to add it as a submodule

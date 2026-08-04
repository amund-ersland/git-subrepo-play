USERS=2

setup_layered_repos(){
    local levels=$1
    local base=${2:-nobase}
    create_output_root_dir $1

    if [[ $1 -eq 2 ]]; then
        create_bare_repo "main-repo"
        create_bare_repo "sub-repo"

        clone $remote_dir/main-repo $root_dir/user1
        make_commit $root_dir/user1/main-repo

        clone $remote_dir/sub-repo $root_dir/user1
        make_commit $root_dir/user1/sub-repo

        add_repo_as_submodule
            --parent_repo "$root_dir/user1/main-repo"
            --child_repo "$remote_dir/sub-repo"

        rm -rf $root_dir/user1/sub-repo


    clone_recursive $remote_dir/main-repo $root_dir/user2
        tree "$root_dir/user2/main-repo"
    fi
}

#===============================================================================
# helpers
#===============================================================================

create_output_root_dir() {
    local name_base="$1"
    name="${name_base}_$(date +%Y-%m-%d_%H:%M:%S)"

    # root for remote repos
    root_dir="/home/amund.ersland/git-play-output/$name"
    remote_dir="$root_dir/remotes"

    # user workspaces
    for n in $(seq 1 "$USERS"); do
        mkdir -p "$root_dir/user$n"
    done
}

create_bare_repo() {
    local name="$1"
    git init --bare "$remote_dir/$name"
}

make_commit(){
    local repo_path=$1
    local msg=${2:-""}

    local dir=$repo_path/files

    if [[ ! -d $dir ]]; then
        mkdir -p $dir
    fi

    local file="$dir/$(uuidgen | md5sum | cut -c1-4).txt"
    last_added=$(basename $file)
    echo "herp derp" > $file
    git -C $repo_path add $file
    git -C $repo_path commit -m "$msg, added $last_added to ./files"
}

make_commit_and_push() {
    make_commit $1 $2
    git -C $1 push
}

clone(){
    local origin_path=$1
    local local_path=$2
    git clone $origin_path "$local_path/$(basename $origin_path)"
}

clone_recursive(){
    local origin_path=$1
    local local_path=$2
    git -c protocol.file.allow=always clone --recursive $origin_path "$local_path/$(basename $origin_path)"
}

add_repo_as_submodule(){
    local parent_repo=""
    local child_repo=""
    local submodule_path=$(basename "$child_repo")

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --parent_repo)
                parent_repo=$2
                shift 2
                ;;
            --child_repo)
                child_repo=$2
                shift 2
                ;;
            --submodule-path)
                submodule_path=$2
                shift 2
                ;;
            *)
                echo -e "\033[31munknown argument $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$child_repo" || -z "$parent_repo" ]]; then
        echo -e "\033[31mMissing required arguments: --main-repo and --remote-sub"
        return 1
    fi

    git -C "$parent_repo" -c protocol.file.allow=always submodule add "$child_repo" "$submodule_path"
    git -C "$parent_repo" add .gitmodules "$submodule_path"
    git -C "$parent_repo" commit -m "Add submodule $(basename "$child_repo")"

    git -C "$parent_repo" -c "protocol.file.allow=always" push
}

PRINT_INFO(){
    echo -e "\033[35m$1\033[0m"
}

PRINT_LINE(){
    printf '\033[35m'
    for i in $(seq 1 80); do printf '='; done
    printf '\033[0m\n'
}

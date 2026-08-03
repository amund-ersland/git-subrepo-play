USERS=2

setup_layered_repos(){
    local levels=$1
    local base=${2:-nobase}
    create_output_root_dir $1

    if [[ $1 -eq 2 ]]; then
        create_bare_repo "main-repo"
        create_bare_repo "sub-repo"

        clone $origins_dir/main-repo $root_dir/user1
        make_commit $root_dir/user1/main-repo

        clone $origins_dir/sub-repo $root_dir/user1
        make_commit $root_dir/user1/sub-repo

        add_repo_as_submodule
            --local_main "$root_dir/user1/main-repo"
            --remote_sub "$origins_dir/sub-repo"

        rm -rf $root_dir/user1/sub-repo


    clone_recursive $origins_dir/main-repo $root_dir/user2
        tree "$root_dir/user2/main-repo"
    fi

}



#===============================================================================
# helpers
#===============================================================================

create_output_root_dir() {
    local base="$1"
    name="${base}_$(date +%Y-%m-%d_%H:%M:%S)"

    root_dir="/home/amund.ersland/git-play-output/$name"
    origins_dir="$root_dir/origins"

    for n in $(seq 1 "$USERS"); do
        mkdir -p "$root_dir/user$n"
    done
}

create_bare_repo() {
    local repo_name="$1"
    local local_main="$origins_dir/$repo_name"
    git init --bare "$local_main"
}

make_commit() {
    local local_main=$1
    local extra=${2:-""}
    local msg=${3:-""}

    dst=$local_main/files

    if [[ ! -d $dst ]]; then
        mkdir -p $dst
    fi

    local file="$dst/$(uuidgen | md5sum | cut -c1-4).txt"
    last_added=$(basename $file)
    echo "herp derp" > $file
    git -C $local_main add $file
    git -C $local_main commit -m "$msg - $last_added"

    if [[ "$extra" == "push" ]]; then
        git -C $local_main push
    fi
}

clone(){
    local origin_path=$1
    local dst_path=$2
    git clone $origin_path "$dst_path/$(basename $origin_path)"
}

clone_recursive(){
    local origin_path=$1
    local dst_path=$2
    git -c protocol.file.allow=always clone --recursive $origin_path "$dst_path/$(basename $origin_path)"
}

add_repo_as_submodule(){
    local submodule_origin=
    local local_main=
    local in_repo_path=$(basename "$submodule_origin")

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -l|--local_main)
                local_main=$2
                shift 2
                ;;
            -o|--remote_sub)
                submodule_origin=$2
                shift 2
                ;;
            -p|--path-in-repo)
                shift 2
                ;;
            *)
                echo -e "\033[31munknown argument $1"
                return
                ;;
        esac
    done

    git -C "$local_main" -c protocol.file.allow=always submodule add "$submodule_origin" "$in_repo_path"
    git -C "$local_main" add .gitmodules "$in_repo_path"
    git -C $local_main commit -m "Add submodule $(basename "$submodule_origin")"

    git -C $local_main -c "protocol.file.allow=always" push
}

PRINT_INFO(){
    echo -e "\033[35m$1\033[0m"
}

PRINT_LINE(){
    printf '\033[35m'
    for i in $(seq 1 80); do printf '='; done
    printf '\033[0m\n'
}

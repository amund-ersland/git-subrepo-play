USERS=2

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
    local repo_path="$origins_dir/$repo_name"
    git init --bare "$repo_path"
}

add_file_to_repo() {
    repo_path=$1
    dst=$repo_path/files

    if [[ ! -d $dst ]]; then
        mkdir -p $dst
    fi

    local file="$dst/$(uuidgen | md5sum | cut -c1-4).txt"
    last_added=$(basename $file)
    echo "herp derp" > $file
    git -C $repo_path add $file
    git -C $repo_path commit -m "Add file $last_added"

    git -C $repo_path push
}

user_clone_repo(){
    local origin_path=$1
    local dst_path=$2
    git clone $origin_path "$dst_path/$(basename $origin_path)"
}

user_clone_recursive(){
    local origin_path=$1
    local dst_path=$2
    git -c protocol.file.allow=always clone --recursive $origin_path "$dst_path/$(basename $origin_path)"
}

add_repo_as_submodule(){
    local submodule_origin=$1
    local repo_path=$2
    local in_repo_path=${3:-$(basename "$submodule_origin")}

    git -C "$repo_path" -c protocol.file.allow=always submodule add "$submodule_origin" "$in_repo_path"
    git -C "$repo_path" add .gitmodules "$in_repo_path"
    git -C $repo_path commit -m "Add submodule $(basename "$submodule_origin")"

    git -C $repo_path -c "protocol.file.allow=always" push
}

PRINT_INFO(){
    echo -e "\033[35m$1\033[0m"
}

PRINT_LINE(){
    printf '\033[35m'
    for i in $(seq 1 80); do printf '='; done
    printf '\033[0m\n'
}

add_random_file_and_push(){
    local repo_path=$1
    local msg=${2:-""}

    cd_into $repo_path
    local dir=files

    if [[ ! -d $dir ]]; then
        run mkdir -p $dir
    fi

    local file="$dir/$(uuidgen | md5sum | cut -c1-4).txt"
    last_added=$(basename $file)
    TEXT "echo \"herp derp\" > $file"
    echo "herp derp" > $file
    run git add $file
    run git commit -m "\"${msg}add $last_added\""

    run git push
}

# private helper: stage a path, commit, push
_add_commit_push(){
    local repo_path=$1
    local path_to_add=$2
    local msg=$3

    cd_into "$repo_path"
    run git add "$path_to_add"
    run git commit -m "\"$msg\""
    run git -c protocol.file.allow=always push
}

commit_push_gitmodules(){
    local repo_path=$1
    local msg=${2:-"update .gitmodules"}

    _add_commit_push "$repo_path" ".gitmodules" "$msg"
}

#===============================================================================
update_superproject_with_submodule(){
    local superproject=$1
    local submodule=$2
    local msg=${3:-"update $(basename "$superproject") with current $submodule"}

    LOG_INFO "## $msg"
    _add_commit_push "$superproject" "$submodule" "$msg"
}

#===============================================================================
# Clone a remote into a local directory.
#   --recursive           clone submodules too (implies -c protocol.file.allow=always
#                         so local file:// submodule remotes are allowed)
#   --recurse <pathspec>  clone submodules matching <pathspec>, e.g.
#                         ':(exclude)child-repo-2'. This writes the pathspec into
#                         the new clone's submodule.active, so excluded submodules
#                         stay inactive and are never checked out.
clone_repo(){
    local remote_path=""
    local local_path=""
    local recursive=""
    local recurse_pathspec=""

    SECTION "parse arguments"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --recursive) recursive="--recursive"; shift ;;
            --recurse)   recurse_pathspec="$2";   shift 2 ;;
            *)
                if [[ -z "$remote_path" ]]; then
                    remote_path="$1"
                else
                    local_path="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$remote_path" || -z "$local_path" ]]; then
        echo -e "\033[31mMissing required arguments: remote_path and/or local_path"
        return 1
    fi

    SECTION "resolve paths and move into the target directory"
    cd_into $local_path
    remote_path=$(realpath $remote_path)
    local_path=$(realpath $local_path)

    SECTION "clone the remote"
    if [[ -n "$recurse_pathspec" ]]; then
        run git -c protocol.file.allow=always clone --recurse-submodules="$recurse_pathspec" $remote_path
    elif [[ -n "$recursive" ]]; then
        run git -c protocol.file.allow=always clone --recursive $remote_path
    else
        run git clone $remote_path
    fi
}

#===============================================================================
pull_superproject(){
    local repo=$(relpath $1)
    LOG_INFO "## pull changes in superproject and update submodules in $repo"
    cd_into $repo
    run git pull
}

#===============================================================================
# Pull the superproject and update its submodules.
#   --init     pass --init   (activate/initialize submodules; re-activates even
#              submodules marked submodule.<name>.active=false)
#   --remote   pass --remote (fetch newest from the submodule's remote branch)
# --recursive is always applied.
update_submodules(){
    local init=""
    local remote=""
    local repo=""

    SECTION "parse arguments"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --init)   init="--init";     shift ;;
            --remote) remote="--remote"; shift ;;
            *)        repo="$1";         shift ;;
        esac
    done

    if [[ -z "$repo" ]]; then
        echo -e "\033[31mMissing required argument: repo path"
        return 1
    fi

    SECTION "pull the superproject, then update its submodules"
    pull_superproject "$repo"
    run git -c protocol.file.allow=always submodule update $remote $init --recursive
}

#===============================================================================
add_repo_as_submodule(){
    local superproject=""
    local child_remote=""

    SECTION "parse arguments"
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

    SECTION "add the submodule and commit the new .gitmodules + gitlink"
    superproject=$(relpath $superproject)
    run cd $superproject
    run git -c protocol.file.allow=always submodule add "$child_remote" "$path_to_submodule"
    run git commit -m "\"Add submodule "$path_to_submodule"\""

    SECTION "push the superproject"
    run git -c "protocol.file.allow=always" push
}

#===============================================================================
checkout_repo(){
    local repo_path=$1
    local commit_ish=$2
    local arg=$3

    cd_into $repo_path
    git checkout $arg $commit_ish
}

#===============================================================================
set_current_branch_upstream(){
    git push -u origin $(git branch --show-current)
}

#===============================================================================
print_repo_status() {
    local superproject=$1
    local submodule=$2
    local strong_title=${3:-"$(realpath $superproject)"}

    cd_into $superproject

    declare -A what_to_command=(
        [submodule current sha]="git -C $submodule rev-parse --short HEAD"
        [submodule tracked sha]="git ls-tree HEAD $submodule | head -1 | cut -d' ' -f3 | cut -c1-7"
        [superproject sha     ]="git rev-parse --short HEAD"
    )

    INFO $LINE

    INFO "\033[1;36m$strong_title\033[0;36m - status of $(basename $superproject) and its submodules"
    TEXT "\nDescription           | sha     | command to run "
    TEXT "----------------------|---------|----------------"
    for what in "${!what_to_command[@]}"; do
        TEXT "$what | $(eval ${what_to_command[$what]}) | ${what_to_command[$what]}"
    done

    INFO "\nSubmodule status \033[0m (git submodule status)"
    TEXT "$(git submodule status)"
    INFO "$LINE\n"
}

#===============================================================================
set_submodule_active(){
    local superproject=$1
    local submodule=$2
    local status=$3
    local where=${4:-"gitmodules"}

    cd_into $superproject
    local flag=false

    if [[ $status == "active" ]]; then
        flag=true
    fi
 
    if [[ $where == "gitmodules" ]]; then
        run git config -f .gitmodules submodule.$submodule.active $flag
    else
        run git config submodule.$submodule.active $flag
    fi
}

#===============================================================================
print_submodule_active_flags(){
    local superproject=$1
    local where=${2:-"gitmodules"}
    
    local strong_title="$(realpath $superproject)"

    cd_into $superproject

    if [[ $where == "gitmodules" ]]; then
        status_cmd="git config -f .gitmodules --get-regexp '^submodule\..*\.active$'"
    else
        status_cmd="git config --get-regexp '^submodule\..*\.active$'"
    fi
    
    INFO "active submodules \033[0m ($status_cmd)"
    TEXT "$(eval $status_cmd)"
}
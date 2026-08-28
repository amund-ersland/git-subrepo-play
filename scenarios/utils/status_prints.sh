print_repo_statuses(){
    local num_users=$1
    local num_children=$2

    for u in $(seq 1 $num_users); do
        if [[ $num_children -eq 1 ]]; then
            print_repo_status $root_dir/user$u/parent-repo \
                    child-repo \
                    "user$u child-repo"
        else
            for c in $(seq 1 $num_children); do
                print_repo_status $root_dir/user$u/parent-repo \
                    child-repo-$c \
                    "user$u child-repo-$c"
            done
        fi
    done
}

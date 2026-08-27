relpath(){
    export abs_path=$1
    echo "$(realpath --relative-to $PWD $abs_path)"
}

ensure_dir(){
    dir=$1
    if [[ $(realpath $dir) != "$PWD" ]]; then
        run cd $(relpath $dir)
    fi
}

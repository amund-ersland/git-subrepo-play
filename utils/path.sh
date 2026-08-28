relpath(){
    export abs_path=$1

    # macOS ships BSD realpath, which lacks the --relative-to flag. GNU coreutils
    # (installed via `brew install coreutils`) provides it as `grealpath`.
    local realpath_bin="realpath"
    if [[ "$(uname)" == "Darwin" ]]; then
        if command -v grealpath >/dev/null 2>&1; then
            realpath_bin="grealpath"
        else
            ERROR "✗ grealpath not found. On macOS the BSD realpath lacks --relative-to."
            ERROR "  Install GNU coreutils with: brew install coreutils"
            return 1
        fi
    fi

    echo "$($realpath_bin --relative-to $PWD $abs_path)"
}

#===============================================================================
cd_into(){
    dir=$1
    if [[ $(realpath $dir) != "$PWD" ]]; then
        run cd $(relpath $dir)
    fi
}

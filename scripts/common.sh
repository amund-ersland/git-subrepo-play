create_output_dir() {
    local base="$1"
    name="${base}_$(date +%Y-%m-%d_%H:%M:%S)"
    mkdir "../outputs/$name"

    output_dir="../outputs/$name"
}

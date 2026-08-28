#===============================================================================
# Assert that two repos are at the same commit SHA.
# Usage: sha_is_equal <path-to-repo-1> <path-to-repo-2>
# Returns 1 and prints an error if the SHAs differ.
sha_is_equal(){
    local repo1=$1
    local repo2=$2

    local sha1 sha2 short1 short2
    sha1=$(git -C "$repo1" rev-parse HEAD)
    sha2=$(git -C "$repo2" rev-parse HEAD)
    short1=$(git -C "$repo1" rev-parse --short HEAD)
    short2=$(git -C "$repo2" rev-parse --short HEAD)

    if [[ "$sha1" == "$sha2" ]]; then
        INFO "✓ sha_is_equal: $(basename $repo1) and $(basename $repo2) are at the same commit ($short1)"
    else
        ERROR "✗ sha_is_equal: $(basename $repo1) ($short1) ≠ $(basename $repo2) ($short2)"
        return 1
    fi
}

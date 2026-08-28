#===============================================================================
# Helper: resolve the checked-out HEAD sha of a repo.
# Prints the sha on success. If the path is not a checked-out repo (e.g. an
# inactive / uninitialised submodule with an empty working tree) it prints
# "<no-checkout>" instead of aborting the script (we run under `set -e`).
_head_sha(){
    local repo=$1
    # -C <repo> without walking up into a parent repo: require a .git here.
    if [[ -e "$repo/.git" ]]; then
        git -C "$repo" rev-parse HEAD 2>/dev/null || echo "<no-checkout>"
    else
        echo "<no-checkout>"
    fi
}

_short_sha(){
    local sha=$1
    if [[ "$sha" == "<no-checkout>" ]]; then
        echo "$sha"
    else
        echo "${sha:0:7}"
    fi
}

#===============================================================================
# Assert that two repos are at the same commit SHA.
# Usage: assert_sha_equal <path-to-repo-1> <path-to-repo-2>
# Returns 1 and prints an error if the SHAs differ.
assert_sha_equal(){
    local repo1=$1
    local repo2=$2

    local sha1 sha2 short1 short2
    sha1=$(_head_sha "$repo1")
    sha2=$(_head_sha "$repo2")
    short1=$(_short_sha "$sha1")
    short2=$(_short_sha "$sha2")

    if [[ "$sha1" == "$sha2" && "$sha1" != "<no-checkout>" ]]; then
        INFO "✅ PASS assert_sha_equal: $(basename $repo1) and $(basename $repo2) are at the same commit ($short1)"
    else
        ERROR "❌ FAIL assert_sha_equal: expected equal but $(basename $repo1) ($short1) ≠ $(basename $repo2) ($short2)"
        return 1
    fi
}

#===============================================================================
# Assert that two repos are NOT at the same commit SHA.
# Usage: assert_sha_not_equal <path-to-repo-1> <path-to-repo-2>
# A repo with no checkout (inactive submodule) also counts as "not equal".
# Returns 1 and prints an error if the SHAs are equal.
assert_sha_not_equal(){
    local repo1=$1
    local repo2=$2

    local sha1 sha2 short1 short2
    sha1=$(_head_sha "$repo1")
    sha2=$(_head_sha "$repo2")
    short1=$(_short_sha "$sha1")
    short2=$(_short_sha "$sha2")

    if [[ "$sha1" != "$sha2" ]]; then
        INFO "✅ PASS assert_sha_not_equal: $(basename $repo1) ($short1) ≠ $(basename $repo2) ($short2) as expected"
    else
        ERROR "❌ FAIL assert_sha_not_equal: expected different but $(basename $repo1) and $(basename $repo2) are both at ($short1)"
        return 1
    fi
}

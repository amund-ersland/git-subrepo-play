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

#===============================================================================
# Helper: capture a repo's current short HEAD sha into a variable in a scenario.
# Usage: before=$(current_sha "$repo")
# Prints the short sha, or "<no-checkout>" if the repo has no working tree.
current_sha(){
    _short_sha "$(_head_sha "$1")"
}

#===============================================================================
# Helper: the submodule commit (gitlink) the superproject has RECORDED for a
# submodule path in its current HEAD tree. This is the pointer a plain
# 'submodule update' (without --remote) checks out. Prints "<no-gitlink>" if the
# path is not a gitlink in HEAD.
_gitlink_sha(){
    local superproject=$1
    local submodule=$2
    git -C "$superproject" rev-parse --short "HEAD:$submodule" 2>/dev/null || echo "<no-gitlink>"
}

#===============================================================================
# Helper: the newest commit on the submodule remote's default branch, i.e. the
# tip a 'submodule update --remote' would move to. Prints "<no-remote-tip>" on
# failure.
_remote_tip_sha(){
    local submodule=$1
    if [[ -e "$submodule/.git" ]]; then
        local branch
        branch=$(git -C "$submodule" rev-parse --abbrev-ref HEAD 2>/dev/null)
        git -C "$submodule" rev-parse --short "origin/$branch" 2>/dev/null || echo "<no-remote-tip>"
    else
        echo "<no-remote-tip>"
    fi
}

#===============================================================================
# Assert that a submodule's checked-out HEAD equals the gitlink RECORDED by the
# superproject. This is the defining behaviour of a plain (non --remote) update
# and of a recursive clone: the recorded pointer is what gets checked out.
# Usage: assert_submodule_matches_gitlink <superproject> <submodule>
assert_submodule_matches_gitlink(){
    local superproject=$1
    local submodule=$2

    local head gitlink
    head=$(_short_sha "$(_head_sha "$superproject/$submodule")")
    gitlink=$(_gitlink_sha "$superproject" "$submodule")

    if [[ "$head" == "$gitlink" && "$head" != "<no-checkout>" ]]; then
        INFO "✅ PASS assert_submodule_matches_gitlink: $submodule HEAD ($head) == pointer recorded in $(basename $superproject) ($gitlink)"
    else
        ERROR "❌ FAIL assert_submodule_matches_gitlink: $submodule HEAD ($head) ≠ recorded pointer ($gitlink)"
        return 1
    fi
}

#===============================================================================
# Assert that a submodule's checked-out HEAD does NOT equal the recorded gitlink.
# This documents 'submodule update --remote', which moves the working tree ahead
# of the pointer the superproject still records (until the pointer is bumped).
# Usage: assert_submodule_differs_gitlink <superproject> <submodule>
assert_submodule_differs_gitlink(){
    local superproject=$1
    local submodule=$2

    local head gitlink
    head=$(_short_sha "$(_head_sha "$superproject/$submodule")")
    gitlink=$(_gitlink_sha "$superproject" "$submodule")

    if [[ "$head" != "$gitlink" && "$head" != "<no-checkout>" ]]; then
        INFO "✅ PASS assert_submodule_differs_gitlink: $submodule HEAD ($head) is ahead of recorded pointer ($gitlink) as expected"
    else
        ERROR "❌ FAIL assert_submodule_differs_gitlink: expected HEAD to differ from recorded pointer but both are ($head)"
        return 1
    fi
}

#===============================================================================
# Assert that a submodule's checked-out HEAD equals the newest commit on its
# remote branch — the tip 'submodule update --remote' should fetch and check out.
# Usage: assert_submodule_at_remote_tip <superproject> <submodule>
assert_submodule_at_remote_tip(){
    local superproject=$1
    local submodule=$2

    local head tip
    head=$(_short_sha "$(_head_sha "$superproject/$submodule")")
    tip=$(_remote_tip_sha "$superproject/$submodule")

    if [[ "$head" == "$tip" && "$head" != "<no-checkout>" ]]; then
        INFO "✅ PASS assert_submodule_at_remote_tip: $submodule HEAD ($head) == remote branch tip ($tip)"
    else
        ERROR "❌ FAIL assert_submodule_at_remote_tip: $submodule HEAD ($head) ≠ remote branch tip ($tip)"
        return 1
    fi
}

#===============================================================================
# Assert that a submodule is INITIALIZED / checked out: the working tree has a
# .git file (or dir) linking it into the superproject. Proves it was actually
# activated, not just that some SHA happens to match.
# Usage: assert_submodule_initialized <superproject> <submodule>
assert_submodule_initialized(){
    local superproject=$1
    local submodule=$2
    local path="$superproject/$submodule"

    if [[ -e "$path/.git" ]]; then
        INFO "✅ PASS assert_submodule_initialized: $submodule is checked out (.git present at $submodule)"
    else
        ERROR "❌ FAIL assert_submodule_initialized: $submodule has no .git — it is not checked out"
        return 1
    fi
}

#===============================================================================
# Assert that a submodule is NOT checked out: no .git and no working-tree files.
# Stronger than assert_sha_not_equal, which also passes for a <no-checkout> repo.
# Usage: assert_submodule_not_checked_out <superproject> <submodule>
assert_submodule_not_checked_out(){
    local superproject=$1
    local submodule=$2
    local path="$superproject/$submodule"

    # Count tracked working-tree entries other than an empty dir / gitlink stub.
    local files
    files=$(find "$path" -mindepth 1 -not -path '*/.git*' 2>/dev/null | head -1)

    if [[ ! -e "$path/.git" && -z "$files" ]]; then
        INFO "✅ PASS assert_submodule_not_checked_out: $submodule has no .git and an empty working tree"
    else
        ERROR "❌ FAIL assert_submodule_not_checked_out: $submodule appears checked out (.git or files present)"
        return 1
    fi
}

#===============================================================================
# Assert a submodule's active flag has an expected value in a given location.
# Usage: assert_active_flag <superproject> <submodule> <true|false> <gitmodules|config>
# Reads from .gitmodules or the local git config depending on <where>.
assert_active_flag(){
    local superproject=$1
    local submodule=$2
    local expected=$3
    local where=${4:-"config"}

    local actual
    if [[ "$where" == "gitmodules" ]]; then
        actual=$(git -C "$superproject" config -f .gitmodules --get "submodule.$submodule.active" 2>/dev/null || echo "<unset>")
    else
        actual=$(git -C "$superproject" config --local --get "submodule.$submodule.active" 2>/dev/null || echo "<unset>")
    fi

    if [[ "$actual" == "$expected" ]]; then
        INFO "✅ PASS assert_active_flag: submodule.$submodule.active == $expected in $where"
    else
        ERROR "❌ FAIL assert_active_flag: submodule.$submodule.active is '$actual' in $where, expected '$expected'"
        return 1
    fi
}

#===============================================================================
# Assert the local config's submodule.active value (the catch-all pathspec git
# writes on a recursive clone, e.g. '.'). Usage:
#   assert_local_submodule_active_pathspec <superproject> <expected>
assert_local_submodule_active_pathspec(){
    local superproject=$1
    local expected=$2

    local actual
    actual=$(git -C "$superproject" config --local --get "submodule.active" 2>/dev/null || echo "<unset>")

    if [[ "$actual" == "$expected" ]]; then
        INFO "✅ PASS assert_local_submodule_active_pathspec: submodule.active == '$expected' in local config"
    else
        ERROR "❌ FAIL assert_local_submodule_active_pathspec: submodule.active is '$actual', expected '$expected'"
        return 1
    fi
}

#===============================================================================
# Assert that a submodule has a url in the superproject's LOCAL config. A set url
# is git's active rule (3): it keeps an initialized submodule active regardless
# of an active=false pushed via .gitmodules.
# Usage: assert_local_url_set <superproject> <submodule>
assert_local_url_set(){
    local superproject=$1
    local submodule=$2

    local url
    url=$(git -C "$superproject" config --local --get "submodule.$submodule.url" 2>/dev/null || echo "")

    if [[ -n "$url" ]]; then
        INFO "✅ PASS assert_local_url_set: submodule.$submodule.url is set in local config ($url)"
    else
        ERROR "❌ FAIL assert_local_url_set: submodule.$submodule.url is NOT set in local config"
        return 1
    fi
}

#===============================================================================
# Assert that a submodule has NO active override key in local config (so its
# active state is decided by the url rule, not an explicit flag).
# Usage: assert_local_active_unset <superproject> <submodule>
assert_local_active_unset(){
    local superproject=$1
    local submodule=$2

    local actual
    actual=$(git -C "$superproject" config --local --get "submodule.$submodule.active" 2>/dev/null || echo "<unset>")

    if [[ "$actual" == "<unset>" ]]; then
        INFO "✅ PASS assert_local_active_unset: submodule.$submodule.active is not set in local config"
    else
        ERROR "❌ FAIL assert_local_active_unset: submodule.$submodule.active is '$actual' in local config, expected unset"
        return 1
    fi
}

#===============================================================================
# Assert that a submodule is still LISTED in .gitmodules (its definition was not
# removed — e.g. excluding at clone time only touches local config).
# Usage: assert_in_gitmodules <superproject> <submodule>
assert_in_gitmodules(){
    local superproject=$1
    local submodule=$2

    if git -C "$superproject" config -f .gitmodules --get "submodule.$submodule.url" >/dev/null 2>&1; then
        INFO "✅ PASS assert_in_gitmodules: $submodule is still declared in .gitmodules"
    else
        ERROR "❌ FAIL assert_in_gitmodules: $submodule is NOT declared in .gitmodules"
        return 1
    fi
}

#===============================================================================
# Assert that a submodule is NO LONGER declared in .gitmodules (its definition
# was removed, e.g. by 'git rm <submodule>'). The inverse of assert_in_gitmodules.
# Usage: assert_not_in_gitmodules <superproject> <submodule>
assert_not_in_gitmodules(){
    local superproject=$1
    local submodule=$2

    if git -C "$superproject" config -f .gitmodules --get "submodule.$submodule.url" >/dev/null 2>&1; then
        ERROR "❌ FAIL assert_not_in_gitmodules: $submodule is STILL declared in .gitmodules"
        return 1
    else
        INFO "✅ PASS assert_not_in_gitmodules: $submodule is no longer declared in .gitmodules"
    fi
}

#===============================================================================
# Assert that a filesystem path EXISTS. Used to prove a removed submodule's
# directory is left behind (stale) for a colleague who merely pulled + updated.
# Usage: assert_path_exists <path> [label]
assert_path_exists(){
    local path=$1
    local label=${2:-"$path"}

    if [[ -e "$path" ]]; then
        INFO "✅ PASS assert_path_exists: $label exists on disk"
    else
        ERROR "❌ FAIL assert_path_exists: $label does not exist"
        return 1
    fi
}

#===============================================================================
# Assert that a filesystem path does NOT exist. Used to prove a submodule's
# directory was genuinely removed (e.g. for the user who ran the removal).
# Usage: assert_path_absent <path> [label]
assert_path_absent(){
    local path=$1
    local label=${2:-"$path"}

    if [[ ! -e "$path" ]]; then
        INFO "✅ PASS assert_path_absent: $label is gone from disk"
    else
        ERROR "❌ FAIL assert_path_absent: $label still exists"
        return 1
    fi
}

#===============================================================================
# Assert that a repo's HEAD moved forward from a previously captured sha.
# Usage:
#   before=$(current_sha "$repo")
#   ...do an update...
#   assert_sha_advanced "$repo" "$before"
assert_sha_advanced(){
    local repo=$1
    local old_sha=$2

    local new_sha
    new_sha=$(_short_sha "$(_head_sha "$repo")")

    if [[ "$new_sha" != "$old_sha" && "$new_sha" != "<no-checkout>" ]]; then
        INFO "✅ PASS assert_sha_advanced: $(basename $repo) moved from $old_sha to $new_sha"
    else
        ERROR "❌ FAIL assert_sha_advanced: $(basename $repo) did not advance (still at $old_sha)"
        return 1
    fi
}

#===============================================================================
# Assert that a repo's HEAD is UNCHANGED from a previously captured sha (e.g. an
# inactive submodule that an update was expected to skip).
# Usage: assert_sha_unchanged "$repo" "$before"
assert_sha_unchanged(){
    local repo=$1
    local old_sha=$2

    local new_sha
    new_sha=$(_short_sha "$(_head_sha "$repo")")

    if [[ "$new_sha" == "$old_sha" ]]; then
        INFO "✅ PASS assert_sha_unchanged: $(basename $repo) stayed at $old_sha as expected"
    else
        ERROR "❌ FAIL assert_sha_unchanged: $(basename $repo) changed from $old_sha to $new_sha (expected no change)"
        return 1
    fi
}

#===============================================================================
# Assert that a repo's working tree is clean (no staged/unstaged changes).
# Usage: assert_clean_worktree <repo>
assert_clean_worktree(){
    local repo=$1

    if [[ ! -e "$repo/.git" ]]; then
        ERROR "❌ FAIL assert_clean_worktree: $(basename $repo) has no .git / no working tree"
        return 1
    fi

    local dirty
    dirty=$(git -C "$repo" status --porcelain)

    if [[ -z "$dirty" ]]; then
        INFO "✅ PASS assert_clean_worktree: $(basename $repo) working tree is clean"
    else
        ERROR "❌ FAIL assert_clean_worktree: $(basename $repo) has uncommitted changes:\n$dirty"
        return 1
    fi
}

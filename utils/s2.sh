#!/bin/bash
set -eo pipefail

source utils/common.sh

# sets up the repos in the same way as s1
# Both users have now a copy of the repos where sub-repo is a submodule of main-repo
s2_init() {
    setup_layered_repos 3 "s2"
}

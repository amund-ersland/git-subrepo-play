#!/bin/bash
set -eo pipefail

for u in utils/*; do source $u; done

parse_args "$@"

LAYERS=2
prefix="$(echo $0 | cut -d _ -f 1 | cut -d / -f 2)"
setup_layered_repos $prefix $LAYERS

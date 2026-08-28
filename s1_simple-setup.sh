#!/bin/bash
set -eo pipefail

# Set to true to run non-interactively (skip all pauses)
SKIP_PAUSE=false

for u in utils/*; do
    source $u
done

LAYERS=2
prefix="$(echo $0 | cut -d _ -f 1 | cut -d / -f 2)"
setup_layered_repos $prefix $LAYERS

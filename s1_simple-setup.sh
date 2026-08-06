#!/bin/bash
set -eo pipefail

source utils/common.sh

LAYERS=2
prefix="$(echo $0 | cut -d _ -f 1 | cut -d / -f 2)"
setup_layered_repos $LAYERS $prefix

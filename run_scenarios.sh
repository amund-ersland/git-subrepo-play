#!/bin/bash
set -eo pipefail

# Run every scenario script in order. Each scenario ends with sha tests; if any
# test fails the scenario exits non-zero and (thanks to set -e) we stop here.
#
# Any args (e.g. -s / --skip-pause) are forwarded to each scenario script.
# When no args are given we default to --skip-pause so a full batch run does
# not stop for interactive pauses.

# run from the demo root regardless of caller CWD
cd "$(dirname "${BASH_SOURCE[0]}")"

# default args when the caller passes none
scenario_args=("$@")
if [ ${#scenario_args[@]} -eq 0 ]; then
    scenario_args=("--skip-pause")
fi

for scenario in scenarios/*/s[0-9]*.sh; do
    echo -e "\n\033[36m▶ Running $scenario\033[0m"
    if ! bash "$scenario" "${scenario_args[@]}"; then
        echo -e "\033[31m✗ $scenario failed — stopping\033[0m" >&2
        exit 1
    fi
    echo -e "\033[32m✓ $scenario passed\033[0m"
done

echo -e "\n\033[32m✅ All scenarios passed\033[0m"

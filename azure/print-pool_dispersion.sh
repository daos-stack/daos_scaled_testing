#!/bin/bash

# set -x
set -e
set -o pipefail

CWD="$(realpath "$(dirname $0)")"

source "$CWD/envs/env.sh"

$RSH_BIN $LOGIN_NODE sudo dmg pool query --json tank | jq -r '((["device"] + [.response.tier_stats[] | .media_type]) | @tsv),((["min"] + [.response.tier_stats[] | .min]) | @tsv),((["mean"] + [.response.tier_stats[] | .mean]) | @tsv),((["max"] + [.response.tier_stats[] | .max]) | @tsv)' | column -t

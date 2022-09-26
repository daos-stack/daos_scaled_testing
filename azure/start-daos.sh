#!/bin/bash

# set -x
set -e
set -o pipefail
CWD="$(realpath "$(dirname $0)")"

source "$CWD/envs/env.sh"

source "$CWD/start-daos_server.sh"
source "$CWD/start-daos_client.sh"

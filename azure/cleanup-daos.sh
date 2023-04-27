#!/bin/bash

# set -x
set -e -o pipefail
CWD="$(realpath "$(dirname $0)")"

source "$CWD/envs/env.sh"

bash "$CWD/cleanup-daos_server.sh"
bash "$CWD/cleanup-daos_client.sh"

#!/bin/bash

# set -x
set -e
set -o pipefail
CWD="$(realpath "$(dirname $0)")"

source "$CWD/envs/env.sh"

cat "$CWD/files/enable-coredumps.sh" | $CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES sudo bash -s

source "$CWD/start-daos_server.sh"
source "$CWD/start-daos_client.sh"

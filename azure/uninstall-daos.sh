#!/bin/bash

# set -x
set -e
set -o pipefail

CWD="$(realpath "$(dirname $0)")"

source "$CWD/envs/env.sh"

echo
echo "[INFO] Removing old DAOS install"
$CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES sudo dnf autoremove daos-server
$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES -x $SERVER_NODES sudo dnf autoremove daos-client daos-client-tests

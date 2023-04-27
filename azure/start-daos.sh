#!/bin/bash

# set -x
set -e
set -o pipefail
CWD="$(realpath "$(dirname $0)")"

source "$CWD/envs/env.sh"

DAOS_BDEV_CFG=${1?"Missing block device configuration (accepted value: 'single_bdev' and 'multi_bdevs')"}

cat "$CWD/files/enable-coredumps.sh" | $CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES sudo bash -s

bash "$CWD/start-daos_server.sh" $DAOS_BDEV_CFG
bash "$CWD/start-daos_client.sh"

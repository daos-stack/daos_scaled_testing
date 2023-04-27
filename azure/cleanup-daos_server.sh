#!/bin/bash

# set -x
set -e
set -o pipefail
CWD="$(realpath "$(dirname $0)")"

source "$CWD/envs/env.sh"

SERVER_NODES=${1:-$SERVER_NODES}

echo  "[INFO] Clean up of DAOS servers"
$CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES sudo systemctl stop daos_server
$CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES sudo rm -rf /tmp/daos_server.log /tmp/daos_engine_0.log /tmp/daos_admin.log

echo "[INFO] Stopping all DAOS processes"
$CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES sudo 'bash -c "killall -q -9 orterun mpirun orted daos_server daos_io_server daos_agent || true"'

{
	cat <<- EOF
	if mountpoint -q /mnt/daos0; then
		echo "[INFO] Cleaning mount point /mnt/daos0"
		rm -fr /mnt/daos0/*
		umount /mnt/daos0
	fi
	EOF
} | $CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES sudo bash


echo "[INFO] Cleaning control plance metadata"
$CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES sudo rm -frv /tmp/daos_server

echo "[INFO] Cleaning huge pages"
$CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES sudo ipcrm --all=shm
$CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES "sudo bash -c '/bin/rm -f /dev/hugepages/spdk_*'"

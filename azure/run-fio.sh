#!/bin/bash

# set -x
set -e -o pipefail

CWD="$(realpath "$(dirname $0)")"

source "$CWD/envs/env.sh"
source "$CWD/envs/env-fio.sh"

FIO_CFG_FILE_PATH=/tmp/dfs.fio
cat "$CWD/files/dfs.fio" | $RSH_BIN $LOGIN_NODE "sudo bash -c 'cat > \"$FIO_CFG_FILE_PATH\"'"
{
	cat <<- EOF
	set -x
	set -e
	set -o pipefail

	echo
	echo "[INF0] DAOS system setup"
	if sudo dmg pool query $DAOS_POOL_NAME > /dev/null 2>&1 ; then
		sudo dmg pool destroy --force --recursive $DAOS_POOL_NAME
		sudo dmg pool list
	fi
	sudo dmg pool create --user=$DAOS_USER_NAME --group=$DAOS_GROUP_NAME --size=$DAOS_POOL_SIZE $DAOS_POOL_NAME
	sudo dmg pool query $DAOS_POOL_NAME

	daos container create --sys-name=daos_server --type=POSIX $DAOS_POOL_NAME $DAOS_CONTAINER_NAME
	daos container query $DAOS_POOL_NAME $DAOS_CONTAINER_NAME

	echo
	echo "[INF0] Launching fio"
	env DAOS_POOL_NAME=$DAOS_POOL_NAME DAOS_CONTAINER_NAME=$DAOS_CONTAINER_NAME $FIO_BIN "$FIO_CFG_FILE_PATH"
	EOF
} | $RSH_BIN $LOGIN_NODE bash -s

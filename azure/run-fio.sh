#!/bin/bash

# set -x
set -e -o pipefail

CWD="$(realpath "$(dirname $0)")"

source "$CWD/envs/env.sh"
source "$CWD/envs/env-fio.sh"

: ${LOG_DIR_ROOT:?'Missing logging output root directory'}
if [[ ! -d "$LOG_DIR_ROOT" ]] ; then
	echo "[ERROR] Invalid logging output root directory: $LOG_DIR_ROOT"
	exit 1
fi

: ${FIO_JOB_FILE:?'Missing fio job file'}
if [[ ! -f "$FIO_JOB_FILE" ]] ; then
	echo "[ERROR] Invalid fio job file path"
	exit 1
fi

: ${FIO_MODE:?'Missing fio mode: accepted mode are "easy" and "hard"'}
case $FIO_MODE in
	easy)
		FIO_BLOCK_SIZE=1M
		FIO_SIZE=10G
		# FIO_SIZE=2M
		# Default DAOS chunck size shuold be updated cautiously
		# DAOS_CHUNK_SIZE=1M
		;;
	hard)
		FIO_BLOCK_SIZE=4K
		FIO_SIZE=2G
		# FIO_SIZE=2M
		# Default DAOS chunck size shuold be updated cautiously
		# DAOS_CHUNK_SIZE=4K
		;;
	*)
		echo "[ERROR] Invalid fio mode \"$FIO_MODE\": accepted mode are \"easy\" and \"hard\"" >&2
		exit 1
		;;
esac

: ${FIO_IODEPTH:?"Missing fio iodepth parameter"}

: ${DAOS_CLIENTS_NB:?'Missing number of DAOS clients'}
DAOS_CLIENT_NODES=$(nodeset -f -I0-$(( $DAOS_CLIENTS_NB - 1)) $CLIENT_NODES)


: ${DAOS_SERVERS_NB:?'Missing number of DAOS servers'}
DAOS_SERVER_NODES=$(nodeset -f -I0-$(( $DAOS_SERVERS_NB - 1 )) $SERVER_NODES)

: ${DAOS_LOGIN_NODE:?"Missing DAOS login node"}

: ${DAOS_RD_FAC:?'Missing DAOS redundancy factor: accepted values are 0, 1 and 2'}
if  ! [[ "$DAOS_RD_FAC" =~ ^(0|2)$ ]] ; then
	echo "[ERROR] Invalid DAOS redundancy factor \"$DAOS_RD_FAC\": accepted value is 0 or 2" >&2
	exit 1
fi

: ${DAOS_OCLASS:?'Missing DAOS file object class'}

bash "$CWD/cleanup-fio.sh"  $DAOS_CLIENT_NODES,localhost

bash "$CWD/start-daos_server.sh" $DAOS_SERVER_NODES
bash "$CWD/start-daos_client.sh" $DAOS_CLIENT_NODES,$DAOS_LOGIN_NODE

DAOS_CONTAINER_PROPERTIES=rd_fac:$DAOS_RD_FAC,rd_lvl:1
if [[ -n $DAOS_CONTAINER_EXTRA_PROPERTIES ]] ; then
	DAOS_CONTAINER_PROPERTIES=$DAOS_CONTAINER_PROPERTIES,$DAOS_CONTAINER_EXTRA_PROPERTIES
fi
echo "[INF0] DAOS system setup"
{
	cat <<- EOF
	set -x
	set -e -o pipefail

	if sudo dmg pool query $DAOS_POOL_NAME > /dev/null 2>&1 ; then
		sudo dmg pool destroy --force --recursive $DAOS_POOL_NAME
		sudo dmg pool list
	fi
	sudo dmg pool create --user=$DAOS_USER_NAME --group=$DAOS_GROUP_NAME --size=$DAOS_POOL_SIZE $DAOS_POOL_NAME
	sudo dmg pool query $DAOS_POOL_NAME

	daos container create --sys-name=daos_server --type=POSIX --properties=$DAOS_CONTAINER_PROPERTIES $DAOS_POOL_NAME $DAOS_CONTAINER_NAME
	daos container query $DAOS_POOL_NAME $DAOS_CONTAINER_NAME
	EOF
} | $RSH_BIN $DAOS_LOGIN_NODE bash -s


echo
echo "[INFO] Benchmark setup"
FIO_LOG_DIR="$LOG_DIR_ROOT/$FIO_MODE/$FIO_IODEPTH/rd_fac$DAOS_RD_FAC/$DAOS_OCLASS"
mkdir -p "$FIO_LOG_DIR"

echo
echo "[INFO] Starting fio server"
{
	cat <<- EOF
	set -x

	sudo pkill -u \$(id -u) fio
	sleep 1
	if sudo pgrep -u \$(id -u) fio ; then
		sudo pkill -9 -u \$(id -u) fio
		sleep 10
	fi

	set -e -o pipefail
	$FIO_BIN --server --daemonize=/tmp/fio-server.pid
	EOF
} | $CLUSH_BIN $CLUSH_OPTS -w $DAOS_CLIENT_NODES bash -s

echo
echo "[INF0] Launching fio on clients $DAOS_CLIENT_NODES"
for hostname in $(nodeset -e $DAOS_CLIENT_NODES) ; do
	FIO_CLIENTS="$FIO_CLIENTS --client=$hostname $FIO_JOB_FILE"
done
FIO_LOG_FILE_NAME=fio-$FIO_MODE-$FIO_IODEPTH-rd_fac$DAOS_RD_FAC-$DAOS_OCLASS-$DAOS_SERVERS_NB-$DAOS_CLIENTS_NB.json
set -x
env	DAOS_POOL_NAME=$DAOS_POOL_NAME \
	DAOS_CONTAINER_NAME=$DAOS_CONTAINER_NAME \
	DAOS_OCLASS=$DAOS_OCLASS \
	FIO_BLOCK_SIZE=$FIO_BLOCK_SIZE \
	FIO_SIZE=$FIO_SIZE \
	FIO_IODEPTH=$FIO_IODEPTH \
	$FIO_BIN --output "$FIO_LOG_DIR/$FIO_LOG_FILE_NAME" --output-format=json $FIO_CLIENTS
set +x

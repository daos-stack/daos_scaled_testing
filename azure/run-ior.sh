#!/bin/bash

# set -x
set -e -o pipefail

CWD="$(realpath "$(dirname $0)")"

LOG_DIR_ROOT=${1:?'Missing logging output root directory'}
if [[ ! -d "$LOG_DIR_ROOT" ]] ; then
	echo "[ERROR] Invalid logging output root directory: $LOG_DIR_ROOT"
	exit 1
fi
IOR_MODE=${2:?'Missing ior mode: accepted mode are "easy" and "hard"'}
if  ! [[ "$IOR_MODE" =~ ^(easy|hard)$ ]] ; then
	echo "[ERROR] Invalid ior mode \"$IOR_MODE\": accepted mode are \"easy\" and \"hard\"" >&2
	exit 1
fi
IOR_FILE_SHARING=${3:?'Missing ior file sharing option: accepted option are "single" and "shared"'}
if  ! [[ "$IOR_FILE_SHARING" =~ ^(single|shared)$ ]] ; then
	echo "[ERROR] Invalid file sharing option \"$IOR_FILE_SHARING\": accepted mode are \"single\" and \"shared\"" >&2
	exit 1
fi
DAOS_REDUNDANCY_FACTOR=${4:?'Missing DAOS redundancy factor: accepted values are 0, 1 and 2'}
if  ! [[ "$DAOS_REDUNDANCY_FACTOR" =~ ^(0|1|2)$ ]] ; then
	echo "[ERROR] Invalid DAOS redundancy factor \"$DAOS_REDUNDANCY_FACTOR\": accepted values are 0, 1 and 2" >&2
	exit 1
fi
DAOS_DIR_OCLASS=${5:?'Missing DAOS directory object class'}
DAOS_OCLASS=${6:?'Missing DAOS file object class'}

source "$CWD/envs/env.sh"
source "$CWD/envs/env-ior_${IOR_MODE}.sh"
source "$CWD/envs/env-ior_${IOR_MODE}_${IOR_FILE_SHARING}.sh"
HOSTFILE_NAME=$($NODESET_BIN -c "$CLIENT_NODES")-nodes.cfg
DAOS_CONTAINER_PROPERTIES=rf:$DAOS_REDUNDANCY_FACTOR,rf_lvl:1
if [[ -n $DAOS_CONTAINER_EXTRA_PROPERTIES ]] ; then
	DAOS_CONTAINER_PROPERTIES=$DAOS_CONTAINER_PROPERTIES,$DAOS_CONTAINER_EXTRA_PROPERTIES
fi

IOR_OPTS+=" --dfs.dir_oclass=$DAOS_DIR_OCLASS --dfs.oclass=$DAOS_OCLASS"

echo
echo "[INF0] Benchmark setup"
LOG_DIR="$LOG_DIR_ROOT/$IOR_MODE/$IOR_FILE_SHARING/rd_fac$DAOS_REDUNDANCY_FACTOR/$DAOS_DIR_OCLASS/$DAOS_OCLASS"
mkdir -p "$LOG_DIR"
$RSH_BIN $LOGIN_NODE mkdir -p /tmp/hostfiles
cat "$CWD/hostfiles/$HOSTFILE_NAME" | $RSH_BIN $LOGIN_NODE "sudo bash -c 'cat > /tmp/hostfiles/$HOSTFILE_NAME'"

for ppn in $MPI_PPN ; do
	echo
	echo "[INF0] Cleanning processes on DAOS client nodes"
	$CLUSH_BIN $CLUSH_OPTS -w $CLIENT_NODES sudo pkill -9 mpirun > /dev/null 2>&1 || true
	$CLUSH_BIN $CLUSH_OPTS -w $CLIENT_NODES sudo pkill -9 ior > /dev/null 2>&1 || true

	nnb=$($NODESET_BIN -c "$CLIENT_NODES")
	np=$(( $nnb * $ppn ))
	LOG_FILE_NAME=$DAOS_CONTAINER_NAME-$($NODESET_BIN -c $SERVER_NODES)-${nnb}_$ppn.log
	if [[ $IOR_MODE == easy ]] ; then
		bs=$(( $DATASET_SIZE / $np ))
		if [[ $bs -gt $IOR_BLOCK_SIZE_MAX ]] ; then
			bs=$IOR_BLOCK_SIZE_MAX
		fi
	elif [[ $IOR_MODE == hard ]] ; then
		sc=$(( ($DATASET_SIZE * 1000000000) / ($IOR_BLOCK_SIZE * $np) ))
	fi

	{
		cat <<- EOF
		# set -x
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

		daos container create --sys-name=daos_server --type=POSIX --properties=$DAOS_CONTAINER_PROPERTIES $DAOS_POOL_NAME $DAOS_CONTAINER_NAME
		daos container query $DAOS_POOL_NAME $DAOS_CONTAINER_NAME

		module load mpi/mpich-x86_64

		echo
		if [[ $IOR_MODE == easy ]] ; then
			echo "[INF0] Running ior easy: nnb=$nnb, ppn=$ppn (np=$np), bs=$bs"
			$MPI_BIN -hostfile "/tmp/hostfiles/$HOSTFILE_NAME" -np $np --ppn $ppn --bind-to socket $IOR_BIN $IOR_OPTS -b ${bs}G 2>&1 | tee /tmp/$LOG_FILE_NAME
		elif [[ $IOR_MODE == hard ]] ; then
			echo "[INF0] Running ior hard: nnb=$nnb, ppn=$ppn (np=$np), sc=$sc"
			$MPI_BIN -hostfile "/tmp/hostfiles/$HOSTFILE_NAME" -np $np --ppn $ppn --bind-to socket $IOR_BIN $IOR_OPTS -s $sc 2>&1 | tee /tmp/$LOG_FILE_NAME
		fi
		EOF
	} | $RSH_BIN $LOGIN_NODE bash
	$RSH_BIN $LOGIN_NODE cat /tmp/$LOG_FILE_NAME > "$LOG_DIR/$LOG_FILE_NAME"
done

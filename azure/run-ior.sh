#!/bin/bash

# set -x
set -e
set -o pipefail

CWD="$(realpath "$(dirname $0)")"

IOR_MODE=${1:?'Missing ior mode: accepted mode are "easy" and "hard"'}
if  ! [[ "$IOR_MODE" =~ ^(easy|hard)$ ]] ; then
	echo "[ERROR] Invalid ior mode \"$IOR_MODE\": accepted mode are \"easy\" and \"hard\"" >&2
	exit 1
fi
IOR_FILE_SHARING_OPT=${2:?'Missing ior file sharing option: accepted option are "single" and "shared"'}
if  ! [[ "$IOR_FILE_SHARING_OPT" =~ ^(single|shared)$ ]] ; then
	echo "[ERROR] Invalid file sharing option \"$IOR_FILE_SHARING_OPT\": accepted mode are \"single\" and \"shared\"" >&2
	exit 1
fi
DAOS_REDUNDANCY_FACTOR=${3:?'Missing DAOS redundancy factor: accepted values are 0, 1 and 2'}
if  ! [[ "$DAOS_REDUNDANCY_FACTOR" =~ ^(0|1|2)$ ]] ; then
	echo "[ERROR] Invalid DAOS redundancy factor \"$DAOS_REDUNDANCY_FACTOR\": accepted values are 0, 1 and 2" >&2
	exit 1
fi

if [[ -n $4 ]] ; then
	IOR_EXTRA_OPTS="$4"
fi

source "$CWD/envs/env.sh"
source "$CWD/envs/env-ior_${IOR_MODE}.sh"
source "$CWD/envs/env-ior_${IOR_MODE}_${IOR_FILE_SHARING_OPT}.sh"
HOSTFILE_NAME=$($NODESET_BIN -c "$CLIENT_NODES")-nodes.cfg
DAOS_CONTAINER_PROPERTIES=rf:$DAOS_REDUNDANCY_FACTOR,rf_lvl:1
if [[ -n $DAOS_CONTAINER_EXTRA_PROPERTIES ]] ; then
	DAOS_CONTAINER_PROPERTIES=$DAOS_CONTAINER_PROPERTIES,$DAOS_CONTAINER_EXTRA_PROPERTIES
fi

echo
echo "[INF0] Benchmark setup"
mkdir -p "$CWD/results/rf$DAOS_REDUNDANCY_FACTOR/$DAOS_CONTAINER_NAME/$TIMESTAMP/"
$RSH_BIN $LOGIN_NODE mkdir -p /tmp/hostfiles
cat "$CWD/hostfiles/$HOSTFILE_NAME" | $RSH_BIN $LOGIN_NODE "sudo bash -c 'cat > /tmp/hostfiles/$HOSTFILE_NAME'"

# for ppn in 1 2 4 6 8 12 16 20 24 28 32
for ppn in 1 4 8 16 32
do
	echo
	echo "[INF0] Cleanning processes on DAOS client nodes"
	$CLUSH_BIN $CLUSH_OPTS -w $CLIENT_NODES sudo pkill -9 mpirun > /dev/null 2>&1 || true
	$CLUSH_BIN $CLUSH_OPTS -w $CLIENT_NODES sudo pkill -9 ior > /dev/null 2>&1 || true

	nnb=$($NODESET_BIN -c "$CLIENT_NODES")
	np=$(( $nnb * $ppn ))
	of=$DAOS_CONTAINER_NAME-$($NODESET_BIN -c $SERVER_NODES)-${nnb}_$ppn.log
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
			$MPI_BIN -hostfile "/tmp/hostfiles/$HOSTFILE_NAME" -np $np --ppn $ppn --bind-to socket $IOR_BIN $IOR_OPTS $IOR_EXTRA_OPTS -b ${bs}G 2>&1 | tee /tmp/$of
		elif [[ $IOR_MODE == hard ]] ; then
			echo "[INF0] Running ior hard: nnb=$nnb, ppn=$ppn (np=$np), sc=$sc"
			$MPI_BIN -hostfile "/tmp/hostfiles/$HOSTFILE_NAME" -np $np --ppn $ppn --bind-to socket $IOR_BIN $IOR_OPTS $IOR_EXTRA_OPTS -s $sc 2>&1 | tee /tmp/$of
		fi
		EOF
	} | $RSH_BIN $LOGIN_NODE bash
	$RSH_BIN $LOGIN_NODE cat /tmp/$of > "$CWD/results/rf$DAOS_REDUNDANCY_FACTOR/$DAOS_CONTAINER_NAME/$TIMESTAMP/$of"
done

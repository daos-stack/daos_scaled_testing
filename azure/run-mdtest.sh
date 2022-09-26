#!/bin/bash

# set -x
set -e
set -o pipefail

CWD="$(realpath "$(dirname $0)")"

MDTEST_MODE=${1:?'Missing mdtest mode: accepted mode are "easy" and "hard"'}
if  ! [[ "$MDTEST_MODE" =~ ^(easy|hard)$ ]] ; then
	echo "[ERROR] Invalid mdtest mode \"$MDTEST_MODE\": accepted mode are \"easy\" and \"hard\"" >&2
	exit 1
fi
DAOS_REDUNDANCY_FACTOR=${2:?'Missing DAOS redundancy factor: accepted values are 0, 1 and 2'}
if  ! [[ "$DAOS_REDUNDANCY_FACTOR" =~ ^(0|1|2)$ ]] ; then
	echo "[ERROR] Invalid DAOS redundancy factor \"$DAOS_REDUNDANCY_FACTOR\": accepted values are 0, 1 and 2" >&2
	exit 1
fi

source "$CWD/envs/env.sh"
source "$CWD/envs/env-mdtest_${MDTEST_MODE}.sh"
HOSTFILE_NAME=$($NODESET_BIN -c "$CLIENT_NODES")-nodes.cfg

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
	$CLUSH_BIN $CLUSH_OPTS -w $CLIENT_NODES sudo pkill -9 mdtest > /dev/null 2>&1 || true

	nnb=$($NODESET_BIN -c "$CLIENT_NODES")
	np=$(( $nnb * $ppn ))
	of=$DAOS_CONTAINER_NAME-$($NODESET_BIN -c $SERVER_NODES)-${nnb}_$ppn.log

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

		daos container create --sys-name=daos_server --type=POSIX --properties rf:$DAOS_REDUNDANCY_FACTOR $DAOS_POOL_NAME $DAOS_CONTAINER_NAME
		daos container query $DAOS_POOL_NAME $DAOS_CONTAINER_NAME

		module load mpi/mpich-x86_64

		echo
		echo "[INF0] Running mdtest: nnb=$nnb, ppn=$ppn (np=$np)"
		$MPI_BIN -hostfile "/tmp/hostfiles/$HOSTFILE_NAME" -np $np --ppn $ppn --bind-to socket $MDTEST_BIN $MDTEST_OPTS 2>&1 | tee /tmp/$of
		EOF
	} | $RSH_BIN $LOGIN_NODE bash
	$RSH_BIN $LOGIN_NODE cat /tmp/$of > "$CWD/results/rf$DAOS_REDUNDANCY_FACTOR/$DAOS_CONTAINER_NAME/$TIMESTAMP/$of"
done

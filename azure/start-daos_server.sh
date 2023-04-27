#!/bin/bash

# set -x
set -e
set -o pipefail
CWD="$(realpath "$(dirname $0)")"

source "$CWD/envs/env.sh"

DAOS_BDEV_CFG=${1?"Missing block device configuration (accepted value: 'single_bdev' and 'multi_bdevs')"}
if  ! [[ "$DAOS_BDEV_CFG" =~ ^(single_bdev|multi_bdevs)$ ]] ; then
	echo "[ERROR] Invalid DAOS block device configuration \"$DAOS_BDEV_CFG\": accepted mode are \"single_bdev\" and \"multi_bdevs\"" >&2
	exit 1
fi
SERVER_NODES=${2:-$SERVER_NODES}

bash "$CWD/cleanup-daos_server.sh" $SERVER_NODES

echo "[INF0] Generating DAOS servers configuration files..."
cat "$CWD/generate-daos_server_cfg.sh" | $CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES "sudo env DAOS_HUGEPAGES_NB=$DAOS_HUGEPAGES_NB bash -s -- $DAOS_BDEV_CFG"

echo "[INF0] Starting DAOS servers..."
$CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES sudo systemctl daemon-reload
$CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES sudo systemctl start daos_server

timeout=10
while [[ $timeout -gt 0 ]] \
	&& ! $CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES sudo systemctl is-active daos_server > /dev/null 2>&1
do
	echo -e -n "[INF0] Waiting DAOS servers to be active: $timeout\r"
	timeout=$(( $timeout - 1 ))
	sleep 1
done
echo

if [[ $timeout -le 0 ]]
then
	echo "[FATAL] Servers not properly started :("
	exit 1
fi

timeout=120
while [[ $timeout -gt 0 ]] \
	&& ! $CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES grep -q -E -e \"SCM format required\" /tmp/daos_server.log 2> /dev/null
do
	echo -e -n "[INF0] Waiting servers to be ready: $timeout\r"
	timeout=$(( $timeout - 1 ))
	sleep 1
done
echo

if [[ $timeout -le 0 ]]
then
	echo "[FATAL] Servers not properly started :("
	exit 1
fi

echo
echo "[INF0] Formating servers..."
$RSH_BIN $ADMIN_NODE sudo dmg storage format -l $(nodeset -e -S, $SERVER_NODES) --force

echo
echo "[INF0] Checking DAOS system storage in 20s..."
sleep 20
sleep_time=1
while ! $RSH_BIN $ADMIN_NODE sudo dmg storage query usage > /dev/null 2>&1 ; do
	echo "[INFO] DAOS system storage not yet ready: sleeping ${sleep_time}s"
	sleep $sleep_time
	((sleep_time++))
done
echo "[INFO] DAOS system storage ready :-)"
$RSH_BIN $ADMIN_NODE sudo dmg storage query usage

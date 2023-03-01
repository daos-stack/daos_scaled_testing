#!/bin/bash


# set -x
set -e
set -o pipefail
CWD="$(realpath "$(dirname $0)")"

source "$CWD/envs/env.sh"

CLIENT_NODES=${1:-$CLIENT_NODES}

source "$CWD/cleanup-daos_client.sh"

echo "[INF0] Copying DAOS agent configuration file..."
cat "$CWD/files/daos_agent.yml" | $CLUSH_BIN $CLUSH_OPTS -w $CLIENT_NODES "sudo bash -c 'cat > /etc/daos/daos_agent.yml'"

echo "[INF0] Starting DAOS agents..."
$CLUSH_BIN $CLUSH_OPTS -w $CLIENT_NODES sudo systemctl daemon-reload
$CLUSH_BIN $CLUSH_OPTS -w $CLIENT_NODES sudo systemctl start daos_agent

timeout=10
while [[ $timeout -gt 0 ]] \
	&& ! $CLUSH_BIN $CLUSH_OPTS -w $CLIENT_NODES sudo systemctl is-active daos_agent > /dev/null 2>&1
do
	echo -e -n "[INF0] Waiting DAOS agent to be active: $timeout\r"
	timeout=$(( $timeout - 1 ))
	sleep 1
done
echo

if [[ $timeout -le 0 ]]
then
	echo "[FATAL] Servers not properly started :("
	exit 1
fi

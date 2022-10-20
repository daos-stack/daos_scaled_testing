#!/bin/bash

# set -x
set -e
set -o pipefail

CWD="$(realpath "$(dirname $0)")"

SERVER_HOSTNAME=${1?'Missing ntttp server hostname'}
CLIENT_HOSTNAME=${2?'Missing ntttp client hostname'}

source "$CWD/envs/env.sh"

SERVER_IP=$(getent hosts $SERVER_HOSTNAME | cut -d' ' -f1)
CLIENT_IP=$(getent hosts $CLIENT_HOSTNAME | cut -d' ' -f1)

echo
echo "[INFO] cleanning up"
$CLUSH_BIN $CLUSH_OPTS -w $SERVER_HOSTNAME -w $CLIENT_HOSTNAME "pkill -e sockperf || true"
$CLUSH_BIN $CLUSH_OPTS -w $SERVER_HOSTNAME -w $CLIENT_HOSTNAME "rm -f /tmp/ntttcp.json"
sleep 1

echo
echo "[INFO] Starting sockperf server on $SERVER_HOSTNAME"
$RSH_BIN $SERVER_HOSTNAME "bash -c 'nohup $SOCKPERF_BIN server --tcp --ip $SERVER_IP --port 9999 &> /tmp/sockperf.log < /dev/null &'"
sleep 1
$RSH_BIN $SERVER_HOSTNAME cat /tmp/sockperf.log

echo
echo "[INFO] Starting sockperf client on $CLIENT_HOSTNAME"
$RSH_BIN $CLIENT_HOSTNAME $SOCKPERF_BIN ping-pong --msg-size 350 --time $SOCKPERF_TIME --tcp --ip $SERVER_IP --port 9999
sleep 1

echo
echo "[INFO] cleanning up"
$CLUSH_BIN $CLUSH_OPTS -w $SERVER_HOSTNAME -w $CLIENT_HOSTNAME "pkill -e sockperf || true"

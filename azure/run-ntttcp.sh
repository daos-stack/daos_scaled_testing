#!/bin/bash

# set -x
set -e
set -o pipefail

CWD="$(realpath "$(dirname $0)")"

RECEIVER_HOSTNAME=${1?'Missing ntttp receiver hostname'}
SENDER_NODESET=${2?'Missing ntttp sender nodeset'}

source "$CWD/envs/env.sh"

RECEIVER_IP=$(getent hosts $RECEIVER_HOSTNAME | cut -d' ' -f1)
SENDER_HOSTNAMES=()
for hostname in $($NODESET_BIN -e $SENDER_NODESET) ; do
	SENDER_HOSTNAMES+=( $hostname )
done

echo
echo "[INFO] cleanning up"
$CLUSH_BIN $CLUSH_OPTS -w $RECEIVER_HOSTNAME -w $SENDER_NODESET "pkill -e ntttcp || true"
$CLUSH_BIN $CLUSH_OPTS -w $RECEIVER_HOSTNAME -w $SENDER_NODESET "rm -f /tmp/ntttcp.json"
sleep 1

echo
echo "[INFO] Starting ntttcp receiver on $RECEIVER_HOSTNAME"
$RSH_BIN $RECEIVER_HOSTNAME $NTTTCP_BIN -r $RECEIVER_IP -D -M -e -t $NTTTCP_DURATION -j /tmp/ntttcp.json
sleep 1
index=1
while [[ $index -lt ${#SENDER_HOSTNAMES[@]} ]] ; do
	hostname=${SENDER_HOSTNAMES[$index]}
	echo
	echo "[INFO] Starting ntttcp sender on $hostname"
	$RSH_BIN $hostname $NTTTCP_BIN -s $RECEIVER_IP -D -t $NTTTCP_DURATION -j /tmp/ntttcp.json
	index=$(( $index + 1 ))
done
sleep 1
hostname=${SENDER_HOSTNAMES[0]}
echo
echo "[INFO] Starting ntttcp sender on $hostname"
$RSH_BIN $hostname $NTTTCP_BIN -s $RECEIVER_IP -L -t $NTTTCP_DURATION -j /tmp/ntttcp.json

sleep 1
mkdir -p "$CWD/results/ntttcp/$TIMESTAMP/"
for hostname in $RECEIVER_HOSTNAME ${SENDER_HOSTNAMES[@]} ; do
	filepath="$CWD/results/ntttcp/$TIMESTAMP/ntttcp-$hostname.json"
	echo
	echo "[INFO] Backing up ntttcp log file $filepath"
	$RSH_BIN $hostname cat /tmp/ntttcp.json > $filepath
done

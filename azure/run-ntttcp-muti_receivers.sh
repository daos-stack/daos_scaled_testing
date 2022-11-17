#!/bin/bash

# set -x
set -e
set -o pipefail

CWD="$(realpath "$(dirname $0)")"

RECEIVER_NODESET=${1?'Missing ntttp receiver nodeset'}
SENDER_HOSTNAME=${2?'Missing ntttp sender hostname'}

source "$CWD/envs/env.sh"

RECEIVER_HOSTNAMES=()
declare -A RECEIVER_IPS
for hostname in $($NODESET_BIN -e $RECEIVER_NODESET) ; do
	RECEIVER_HOSTNAMES+=($hostname)
	RECEIVER_IPS[$hostname]=$(getent hosts $hostname | cut -d' ' -f1)
done
SENDER_IP=$(getent hosts $SENDER_HOSTNAME | cut -d' ' -f1)

echo "[INFO] cleanning up"
$CLUSH_BIN $CLUSH_OPTS -w $RECEIVER_NODESET -w $SENDER_HOSTNAME "pkill -e ntttcp || true"
$CLUSH_BIN $CLUSH_OPTS -w $RECEIVER_NODESET -w $SENDER_HOSTNAME "rm -fv /tmp/ntttcp*.json"
sleep 1

source_port=25001
destination_port=5001
echo
for hostname in ${RECEIVER_HOSTNAMES[@]} ; do
	echo "[INFO] Starting ntttcp receivers on $hostname: source_port=$source_port destination_port=$destination_port"
	$RSH_BIN $hostname $NTTTCP_BIN -r ${RECEIVER_IPS[$hostname]} -f $source_port -p $destination_port -D -e -t $NTTTCP_DURATION -j /tmp/ntttcp.json > /dev/null
	source_port=$(( $source_port + 1000 ))
	destination_port=$(( $destination_port + 1000 ))
done
sleep 1

echo
{
	cat <<- EOF
	# set -x
	set -e
	set -o pipefail

	declare -A RECEIVER_IPS
	for hostname in ${RECEIVER_HOSTNAMES[@]} ; do
		RECEIVER_IPS[\$hostname]=\$(getent hosts \$hostname | cut -d' ' -f1)
	done

	rm -fr /tmp/ntttcp
	mkdir /tmp/ntttcp
	ntttcp_pids=()
	source_port=25001
	destination_port=5001
	for hostname in ${RECEIVER_HOSTNAMES[@]} ; do
		echo "[INFO] Starting ntttcp senders on $SENDER_HOSTNAME: receiver_hostname=\$hostname source_port=\$source_port destination_port=\$destination_port"
		$NTTTCP_BIN -s \${RECEIVER_IPS[\$hostname]} -f \$source_port -p \$destination_port -t $NTTTCP_DURATION -j /tmp/ntttcp/\$hostname.json > /dev/null &
		ntttcp_pids+=( \$! )
		source_port=\$(( \$source_port + 1000 ))
		destination_port=\$(( \$destination_port + 1000 ))
	done

	echo
	for pid in \${ntttcp_pids[*]} ; do
		echo "Waiting for sender process \$pid"
		wait \$pid
	done
	EOF
} | $RSH_BIN $SENDER_HOSTNAME bash
sleep 1


echo
mkdir -p "$CWD/results/ntttcp-multi_receivers/$TIMESTAMP/"
for hostname in ${RECEIVER_HOSTNAMES[@]} ; do
	filepath="$CWD/results/ntttcp-multi_receivers/$TIMESTAMP/ntttcp-$hostname.json"
	echo "[INFO] Backing up ntttcp log file $filepath"
	$RSH_BIN $hostname cat /tmp/ntttcp.json > $filepath
done
for filename in $($RSH_BIN $SENDER_HOSTNAME /bin/ls /tmp/ntttcp) ; do
	filepath="$CWD/results/ntttcp-multi_receivers/$TIMESTAMP/ntttcp-$SENDER_HOSTNAME.$filename"
	echo "[INFO] Backing up ntttcp log file $filepath"
	$RSH_BIN $SENDER_HOSTNAME cat /tmp/ntttcp/$filename > $filepath
done

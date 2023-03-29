#!/bin/bash

# set -x
# set -e -o pipefail

CWD="$(realpath "$(dirname $0)")"

LOG_DIR_ROOT=${1:?'Missing logging output root directory'}
if [[ ! -d "$LOG_DIR_ROOT" ]] ; then
	echo "[ERROR] Invalid logging output root directory: $LOG_DIR_ROOT"
	exit 1
fi

source "$CWD/envs/env.sh"

trap epilogue INT

function epilogue()
{
	echo
	echo "[INFO] Generate dmesg log files"
	{
		cat <<-EOF
		# set -x
		set -e -o pipefail

		dmesg -H > /tmp/monitor-dmesg.log
		EOF
	} | $CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES bash -s

	echo
	echo "[INFO] Cleanp of DAOS server nodes monitoring daemons"
	{
		cat <<- EOF
		# set -x
		set -e -o pipefail

		echo
		echo "[INF0] Kill monitoring daemons"
		for item in /tmp/monitor-daos_engine.log /tmp/monitor-free.log /tmp/monitor-tmpfs.log ; do
			sudo pkill -f \$item || true
		done
		sleep 3
		for item in /tmp/monitor-daos_engine.log /tmp/monitor-free.log /tmp/monitor-tmpfs.log ; do
			if pgrep -f \$item &> /dev/null ; then
				sudo pkill -9 -f \$item || true
			fi
		done
		EOF
	} | $CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES bash -s

	echo
	echo "[INFO] Download log files"
	remote_files=(
	/tmp/daos_admin.log
	/tmp/daos_engine_0.log
	/tmp/daos_server.log
	/tmp/monitor-dmesg.log
	/tmp/monitor-daos_engine.log
	/tmp/monitor-free.log
	/tmp/monitor-tmpfs.log
	)
	$CLUSH_BIN -w $SERVER_NODES --rcopy ${remote_files[*]} --dest $LOG_DIR_ROOT

	exit 0
}

echo
echo "[INFO] Start monitoring DAOS server nodes health"
{
	UPDATE_LATENCY=1
	cat <<- EOF
	# set -x
	set -e -o pipefail

	echo
	echo "[INF0] Start monitoring memory of the daos_engine"
	> /tmp/monitor-daos_engine.log
	nohup sudo bash -c 'while true ; do echo "### \$(date "+%F %T")" >> /tmp/monitor-daos_engine.log ; ps --no-headers -wly -p \$(pgrep daos_engine) >> /tmp/monitor-daos_engine.log 2>&1 ; sleep $UPDATE_LATENCY ; done' 0<&- 1>&- 2>&- &

	echo
	echo "[INF0] Start monitoring memory of the nodes"
	> /tmp/monitor-free.log
	nohup sudo bash -c 'while true ; do echo "### \$(date "+%F %T")" >> /tmp/monitor-free.log ; free -blw >> /tmp/monitor-free.log 2>&1 ; sleep $UPDATE_LATENCY ; done' 0<&- 1>&- 2>&- &

	echo
	echo "[INF0] Start monitoring tmpfs of the nodes"
	> /tmp/monitor-tmpfs.log
	nohup sudo bash -c 'while true ; do echo "### \$(date "+%F %T")" >> /tmp/monitor-tmpfs.log ; df -t tmpfs | grep daos >> /tmp/monitor-tmpfs.log 2>&1 ; sleep $UPDATE_LATENCY ; done' 0<&- 1>&- 2>&- &
	EOF
} | $CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES bash -s

while $CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES sudo "bash -c '! coredumpctl list --quiet'" ; do
	echo -e -n "\033[1K\r[INFO] Last monitoring: $(date)"
	sleep 1
done
echo -e "\n[INFO] Coredump detected: $(date)"

echo -e "[INFO] Sleeping 10s before dumping logs"
sleep 10

epilogue

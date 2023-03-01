#!/bin/bash

# set -x
set -e -o pipefail

CWD="$(realpath "$(dirname $0)")"

source "$CWD/envs/env.sh"
source "$CWD/envs/env-fio.sh"

FIO_NODES=${1:?'Missing FIO nodes'}

echo
echo "[INFO] Stopping fio server"
{
	cat <<- EOF
	set -x

	sudo pkill -u \$(id -u) fio
	sleep 1
	if sudo pgrep -u \$(id -u) fio ; then
		sudo pkill -9 -u \$(id -u) fio
		sleep 10
	fi
	EOF
} | $CLUSH_BIN $CLUSH_OPTS -w $FIO_NODES bash -s

#!/bin/bash

# set -x
set -e -o pipefail

CWD="$(realpath "$(dirname $0)")"

source "$CWD/envs/env.sh"

set -x
for hostname in $(nodeset -e $SERVER_NODES) ; do
	mkdir -p "$CWD/debug/$TIMESTAMP/cores/$hostname" "$CWD/debug/$TIMESTAMP/logs/$hostname"
	scp $hostname:"/tmp/daos_*.log" "$CWD/debug/$TIMESTAMP/logs/$hostname"
	# ssh $hostname sudo tar -C /var/lib/systemd/coredump/ -c . | tar -C "$CWD/debug/$TIMESTAMP/cores/$hostname" -xv
done

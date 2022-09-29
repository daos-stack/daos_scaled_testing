#!/bin/bash

# set -x
set -e
set -o pipefail

CWD="$(realpath "$(dirname $0)")"

# XXX ntttcp seems to not support more than 8 senders
# for index in {1..8} ; do
# 	echo
# 	echo
# 	echo "======================================================================================="
# 	echo "== number of senders: $index"
# 	time bash $CWD/run-ntttcp.sh daos-server-01 "daos-client-[01-0$index]"
# done
#
# for index in {1..8} ; do
# 	echo
# 	echo
# 	echo "======================================================================================="
# 	echo "== number of senders: $index"
# 	time bash $CWD/run-ntttcp.sh daos-client-18 "daos-client-[01-0$index]"
# done
#
# for index in {1..8} ; do
# 	echo
# 	echo
# 	echo "======================================================================================="
# 	echo "== number of senders: $index"
# 	time bash $CWD/run-ntttcp.sh daos-server-10 "daos-server-[01-0$index]"
# done

for index in {1..8} ; do
	echo
	echo
	echo "======================================================================================="
	echo "== number of senders: $index"
	time bash $CWD/run-ntttcp.sh daos-client-01 "daos-server-[01-0$index]"
done

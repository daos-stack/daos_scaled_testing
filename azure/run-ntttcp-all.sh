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
# 	time bash $CWD/run-ntttcp.sh daos-serv000001 "daos-clie0000[01-0$index]"
# done
#
# for index in {1..8} ; do
# 	echo
# 	echo
# 	echo "======================================================================================="
# 	echo "== number of senders: $index"
# 	time bash $CWD/run-ntttcp.sh daos-clie000009 "daos-clie0000[01-0$index]"
# done
#
for index in {1..8} ; do
	echo
	echo
	echo "======================================================================================="
	echo "== number of senders: $index"
	time bash $CWD/run-ntttcp.sh daos-serv000009 "daos-serv0000[01-0$index]"
done

for index in {1..8} ; do
	echo
	echo
	echo "======================================================================================="
	echo "== number of senders: $index"
	time bash $CWD/run-ntttcp.sh daos-clie000001 "daos-serv0000[01-0$index]"
done

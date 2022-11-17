#!/bin/bash

# set -x
set -e
set -o pipefail

CWD="$(realpath "$(dirname $0)")"

# XXX ntttcp seems to not support more than 8 senders
for index in {1..8} ; do
	echo
	echo
	echo "======================================================================================="
	echo "== daos-clie0000[01-0$index]" daos-serv000001
	time bash $CWD/run-ntttcp-muti_receivers.sh "daos-clie0000[01-0$index]" daos-serv000001
done

for index in {1..8} ; do
	echo
	echo
	echo "======================================================================================="
	echo "== daos-clie0000[01-0$index]" daos-clie000009
	time bash $CWD/run-ntttcp-muti_receivers.sh "daos-clie0000[01-0$index]" daos-clie000009
done

for index in {1..8} ; do
	echo
	echo
	echo "======================================================================================="
	echo "== daos-serv0000[01-0$index]" daos-serv000009
	time bash $CWD/run-ntttcp-muti_receivers.sh "daos-serv0000[01-0$index]" daos-serv000009
done

for index in {1..8} ; do
	echo
	echo
	echo "======================================================================================="
	echo "== daos-serv0000[01-0$index] daos-clie000001"
	time bash $CWD/run-ntttcp-muti_receivers.sh "daos-serv0000[01-0$index]" daos-clie000001
done

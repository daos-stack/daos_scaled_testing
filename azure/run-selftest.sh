#!/bin/bash

# set -x
set -e
set -o pipefail

CWD="$(realpath "$(dirname $0)")"

source "$CWD/envs/env.sh"

echo
echo "[INFO] cleanning up"
$RSH_BIN $LOGIN_NODE "pkill -e self_test || true"
sleep 1

mkdir -p  "$CWD/results/self_test/$TIMESTAMP"
# SELFTEST_EXTRA_OPTS="--message-size '(0 0) (b1048576 0) (0 b1048576) (b1048576 b1048576)' --repetitions 100000"
SELFTEST_EXTRA_OPTS="--message-size '(0 0)' --repetitions 1000000"
# for rank in {0..9} ; do
# for rank in 0 1 3 5 7 9 ; do
# for rank in 0 ; do
# for rank in 0 1 3 5 7 9 ; do
for rank in 0 1 3 4 6 8 ; do
	# for inflight_rpc in 1 4 8 16 24 32 64 ; do
	for inflight_rpc in 4 8 16 24 32 64 ; do
		of=self_test-$rank-$inflight_rpc.log
		{
			cat <<- EOF
			set -x
			set -e -o pipefail

			time $SELFTEST_BIN $SELFTEST_OPTS $SELFTEST_EXTRA_OPTS --endpoint "0-$rank:0-7" --max-inflight-rpcs $inflight_rpc 2>&1 | tee /tmp/$of
			EOF
		} | $RSH_BIN $CLIENT_NODES bash -s
		$RSH_BIN $CLIENT_NODES cat /tmp/$of > "$CWD/results/self_test/$TIMESTAMP/$of"
	done
done

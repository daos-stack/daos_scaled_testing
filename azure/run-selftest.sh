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

of=self_test.log
{
	cat <<- EOF
	# set -x
	set -e
	set -o pipefail

	$SELFTEST_BIN $SELFTEST_OPTS 2>&1 | tee /tmp/$of
	EOF
} | $RSH_BIN $LOGIN_NODE bash
mkdir -p  "$CWD/results/self_test/$TIMESTAMP"
$RSH_BIN $LOGIN_NODE cat /tmp/$of > "$CWD/results/self_test/$TIMESTAMP/$of"

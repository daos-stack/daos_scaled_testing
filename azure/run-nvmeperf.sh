#!/bin/bash

# set -x
set -e
set -o pipefail

CWD="$(realpath "$(dirname $0)")"

source "$CWD/envs/env.sh"

source "$CWD/cleanup-daos_server.sh"

mkdir -p  "$CWD/results/spdk_nvme_perf/$TIMESTAMP"
for size in 4096 1048576 ; do
	for operation in read write ; do
		echo
		echo "[INFO] Running NVMe perf test: size=$size operation=$operation"
		ofp=/tmp/spdk_nvme_perf-$size-$operation.log
		{
			cat <<- EOF
			# set -x
			set -e
			set -o pipefail

			DAOS_NVME_ID=\$(sudo lspci | grep "Non-Volatile memory controller" | cut -d" "  -f1)
			sudo $NVMEPERF_BIN $NVMEPERF_OPTS -b \$DAOS_NVME_ID -o $size -w $operation /dev/nvme0n1 2>&1 | tee $ofp
			EOF
		} | $CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES bash

		$CLUSH_BIN --rcopy -w $SERVER_NODES --dest "$CWD/results/spdk_nvme_perf/$TIMESTAMP" $ofp
	done
done

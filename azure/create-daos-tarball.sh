#!/bin/bash

# set -x
set -e -o pipefail

CWD="$(realpath "$(dirname $0)")"

DAOS_RPMS=${1:?'Missing DAOS RPMS directory'}
if [[ ! -d "$DAOS_RPMS" ]] ; then
	echo "[ERROR] Invalid input DAOS RPMS directory"
	exit 1
fi

DAOS_DEPS=(
	argobots
	compat-hwloc1
	dpdk
	hdf5-mpich
	libfabric
	libisa-l
	libisa-l_crypto
	libpmem
	libpmemobj
	libpmempool
	librpmem
	mercury
	spdk
	spdk-tools
)

mkdir daos-el8
cp -av "$DAOS_RPMS/"*.rpm daos-el8
pushd "$PWD/daos-el8" &>/dev/null
dnf download -y ${DAOS_DEPS[@]}
popd &>/dev/null
tar cvJf daos-el8.txz daos-el8
rm -fr daos-el8

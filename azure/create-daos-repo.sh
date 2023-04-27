#!/bin/bash

# set -x
set -e -o pipefail

CWD="$(realpath "$(dirname $0)")"

DAOS_PKGS=(
	argobots
	compat-hwloc1
	daos
	daos-admin
	daos-admin-debuginfo
	daos-client
	daos-client-debuginfo
	daos-client-tests
	daos-client-tests-debuginfo
	daos-client-tests-openmpi
	daos-client-tests-openmpi-debuginfo
	daos-debuginfo
	daos-debugsource
	daos-devel
	daos-firmware
	daos-firmware-debuginfo
	daos-mofed-shim
	daos-serialize
	daos-serialize-debuginfo
	daos-server
	daos-server-debuginfo
	daos-server-tests
	daos-server-tests-debuginfo
	daos-tests
	daos-tests-internal
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
	# spdk-22.01.2-1.el8
	# spdk-tools-22.01.2-1.el8
)

mkdir daos-master-el8
pushd "$PWD/daos-master-el8" &>/dev/null
dnf download -y ${DAOS_PKGS[@]}
popd &>/dev/null
tar cvJf daos-master-el8.txz daos-master-el8
rm -fr daos-master-el8

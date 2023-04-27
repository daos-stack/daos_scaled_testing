#!/bin/bash

CLIENT_NODES=daos-clie000000
for index in {1..15} ; do
	CLIENT_NODES="$CLIENT_NODES $(printf "daos-clie%06x" $index)"
done
CLIENT_NODES=$(nodeset -f $CLIENT_NODES)
# CLIENT_NODES=daos-serv000009

# CLIENT_NODES=daos-serv000001
# for index in {2..9} ; do
# 	CLIENT_NODES="$CLIENT_NODES $(printf "daos-serv%06x" $index)"
# done
# CLIENT_NODES=$(nodeset -f $CLIENT_NODES)

SERVER_NODES=daos-serv000000
for index in {1..9} ; do
# for index in {1..8} ; do
	SERVER_NODES="$SERVER_NODES $(printf "daos-serv%06x" $index)"
done
SERVER_NODES=$(nodeset -f $SERVER_NODES)

LOGIN_NODE=daos-clie000000
ADMIN_NODE=$LOGIN_NODE
ALL_NODES=$SERVER_NODES,$CLIENT_NODES

DAOS_HUGEPAGES_NB=4092
SYS_HUGEPAGES_NB=4164

declare -A dir_oclasses=(
[0]="SX S1"
[2]="RP_3GX RP_3G1"
)

declare -A oclasses=(
[0]="SX S1"
[2]="EC_8P2GX RP_3GX EC_8P2G1 RP_3G1"
)

declare -A chunk_size=(
[SX]=1M
[S1]=1M
[EC_8P2GX]=8M
[RP_3GX]=3M
[EC_8P2G1]=8M
[RP_3G1]=3M
)

declare -A replication_method=(
[SX]=no_replication
[S1]=no_replication
[EC_8P2GX]=erasure_code
[RP_3GX]=replication
[EC_8P2G1]=erasure_code
[RP_3G1]=replication
)

DAOS_POOL_SIZE=100%
DAOS_POOL_NAME=tank
DAOS_USER_NAME=azureuser
DAOS_GROUP_NAME=azureuser

MPI_BIN=mpirun
MPI_MODULE=mpi/mpich-x86_64
MPI_PPN="1 2 4 8 16 32"

IOR_BIN="$HOME/local/bin/ior"
IOR_BLOCK_SIZE_MAX=1000
# IOR_OPTS="-a DFS -r -R -w -W -o /testfile --dfs.group=daos_server --dfs.pool=$DAOS_POOL_NAME"
IOR_OPTS="-a DFS -i 1 -r -w -o /testfile --dfs.group=daos_server --dfs.pool=$DAOS_POOL_NAME"

MDTEST_BIN="$HOME/local/bin/mdtest"
# XXX Too large values
MDTEST_STONEWALL=120
MDTEST_ITEMS=10000000
# XXX Acceptable values
# MDTEST_STONEWALL=30
# MDTEST_ITEMS=1000000
MDTEST_OPTS="-a DFS -F -P -G 27 -N 1 -d /testdir -p 10 -Y -v -C -T -r -u -L -i 1 -W $MDTEST_STONEWALL -z 0 -n $MDTEST_ITEMS --dfs.pool=$DAOS_POOL_NAME"

FIO_BIN="$HOME/local/bin/fio"

RSH_BIN=ssh

CLUSH_BIN=clush
CLUSH_OPTS="-BL -S"

NODESET_BIN=nodeset

NTTTCP_BIN=$HOME/local/bin/ntttcp
NTTTCP_DURATION=300

SOCKPERF_BIN=$HOME/local/bin/sockperf
SOCKPERF_TIME=120

SELFTEST_BIN=self_test
SELFTEST_OPTS="-u --group-name daos_server"

NVMEPERF_BIN=spdk_nvme_perf
NVMEPERF_OPTS="-q 16 -c 0xff -t 120"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)

function generate-daos_control_cfg
{
	cat <<- EOF
	name: daos_server
	port: 10001
	hostlist:
	EOF

	for hostname in $(nodeset -e $SERVER_NODES) ; do
		echo "  - $hostname"
	done

	cat <<- EOF

	transport_config:
	  allow_insecure: true
	EOF
}

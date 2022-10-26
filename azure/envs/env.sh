#!/bin/bash

CLIENT_NODES=daos-clie000000
for index in {1..15} ; do
	CLIENT_NODES="$CLIENT_NODES $(printf "daos-clie%06x" $index)"
done
CLIENT_NODES=$(nodeset -f $CLIENT_NODES)

SERVER_NODES=daos-serv000000
for index in {1..9} ; do
	SERVER_NODES="$SERVER_NODES $(printf "daos-serv%06x" $index)"
done
SERVER_NODES=$(nodeset -f $SERVER_NODES)

LOGIN_NODE=daos-clie000000
ADMIN_NODE=$LOGIN_NODE
ALL_NODES=$SERVER_NODES,$CLIENT_NODES

DAOS_HUGEPAGES_NB=4092
SYS_HUGEPAGES_NB=4164

DAOS_POOL_SIZE=6TB
DAOS_POOL_NAME=tank
DAOS_USER_NAME=azureuser
DAOS_GROUP_NAME=azureuser

MPI_BIN=mpirun
MPI_MODULE=mpi/mpich-x86_64

IOR_BIN="$HOME/local/bin/ior"
IOR_BLOCK_SIZE_MAX=1000
# IOR_OPTS="-a DFS -r -R -w -W -o /testfile --dfs.group=daos_server --dfs.pool=$DAOS_POOL_NAME"
IOR_OPTS="-a DFS -i 1 -r -w -o /testfile --dfs.group=daos_server --dfs.pool=$DAOS_POOL_NAME"

MDTEST_BIN="$HOME/local/bin/mdtest"
MDTEST_STONEWALL=120
# MDTEST_OCLASS_OPTS=(
# "--dfs.dir_oclass=SX --dfs.oclass=SX"
# "--dfs.dir_oclass=RP_2GX --dfs.oclass=EC_8P1GX"
# "--dfs.dir_oclass=RP_3GX --dfs.oclass=EC_8P2GX"
# )
# MDTEST_OCLASS_OPTS=(
# "--dfs.dir_oclass=SX --dfs.oclass=S1"
# "--dfs.dir_oclass=RP_2GX --dfs.oclass=EC_8P1G1"
# "--dfs.dir_oclass=RP_3GX --dfs.oclass=EC_8P2G1"
# )
MDTEST_OPTS="-a DFS -F -P -G 27 -N 1 -d /testdir -p 10 -Y -v -C -T -r -u -L -i 1 -W $MDTEST_STONEWALL -z 0 -n 10000000 --dfs.pool=$DAOS_POOL_NAME --dfs.chunk_size=8M"

RSH_BIN=ssh

CLUSH_BIN=clush
CLUSH_OPTS="-bL -S"

NODESET_BIN=nodeset

NTTTCP_BIN=$HOME/local/bin/ntttcp
NTTTCP_DURATION=300

SOCKPERF_BIN=$HOME/local/bin/sockperf
SOCKPERF_TIME=120

SELFTEST_BIN=self_test
SELFTEST_OPTS="-u --group-name daos_server --endpoint 0-9:2 --message-size '(0 0) (b1048576 0) (0 b1048576) (b1048576 b1048576)' --max-inflight-rpcs 16 --repetitions 100000"

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

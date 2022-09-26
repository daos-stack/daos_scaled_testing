#!/bin/bash

CLIENT_NODES=daos-client-[01-16]
SERVER_NODES=daos-server-[01-10]
LOGIN_NODE=daos-client-01
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
MDTEST_OCLASS_OPTS=(
"--dfs.dir_oclass=SX --dfs.oclass=SX"
"--dfs.dir_oclass=RP_2GX --dfs.oclass=EC_8P1GX"
"--dfs.dir_oclass=RP_3GX --dfs.oclass=EC_8P2GX"
)
# MDTEST_OCLASS_OPTS=(
# "--dfs.dir_oclass=SX --dfs.oclass=S1"
# "--dfs.dir_oclass=RP_2GX --dfs.oclass=EC_8P1G1"
# "--dfs.dir_oclass=RP_3GX --dfs.oclass=EC_8P2G1"
# )
MDTEST_OPTS="-a DFS -F -P -G 27 -N 1 -d /testdir -p 10 -Y -v -C -T -r -u -L -i 1 -W $MDTEST_STONEWALL -z 0 -n 10000000 --dfs.pool=$DAOS_POOL_NAME --dfs.chunk_size=8M ${MDTEST_OCLASS_OPTS[$DAOS_REDUNDANCY_FACTOR]}"

RSH_BIN=ssh

CLUSH_BIN=clush
CLUSH_OPTS="-bL -S"

NODESET_BIN=nodeset

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

#!/bin/bash

export PATH
export LD_LIBRARY_PATH
export EMAIL
export DAOS_DIR
export TESTCASE
export LOGS=$RES_DIR/$(date +%Y%m%d)/$TESTCASE
mkdir -p $LOGS

export DAOS_SERVERS
export DAOS_CLIENTS
export INFLIGHT
export XFER_SIZE
export BLOCK_SIZE
export PPC
export OMPI_TIMEOUT

pushd $DST_DIR

echo Running $TESTCASE
sbatch -J $JOBNAME -t $TIMEOUT --mail-user=$EMAIL -N $NNODE -n $NCORE -p $PARTITION tests.sh $TEST_GROUP

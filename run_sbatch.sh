#!/bin/bash

TIMESTAMP=$(date +%Y%m%d)

export PATH
export LD_LIBRARY_PATH
export EMAIL
export DAOS_DIR
export TESTCASE
export LOGS=${RES_DIR}/${TIMESTAMP}/${TESTCASE}
export RUN_DIR=${LOGS}/log_${DAOS_SERVERS}
mkdir -p ${RUN_DIR}

export DAOS_SERVERS
export DAOS_CLIENTS
export INFLIGHT
export XFER_SIZE
export BLOCK_SIZE
export PPC
export OMPI_TIMEOUT

pushd ${RUN_DIR}

# Get TACC usage status
/usr/local/etc/taccinfo > ${RUN_DIR}/tacc_usage_status.txt 2>&1

SLURM_JOB="$(sbatch -J $JOBNAME -t $TIMEOUT --mail-user=$EMAIL -N $NNODE -n $NCORE -p $PARTITION ${DST_DIR}/tests.sh $TEST_GROUP)"

echo "$(printf '%80s\n' | tr ' ' =)
Running ${TESTCASE} with ${DAOS_SERVERS} servers and ${DAOS_CLIENTS} clients
${SLURM_JOB}" |& tee -a ${RES_DIR}/${TIMESTAMP}/job_list.txt

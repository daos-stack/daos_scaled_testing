#!/bin/bash

TIMESTAMP=$(date +%Y%m%d)

export PATH
export LD_LIBRARY_PATH
export EMAIL
export DAOS_DIR
export TESTCASE
export LOGS=${RES_DIR}/${TIMESTAMP}/${TESTCASE}
export RUN_DIR=${LOGS}/log_${DAOS_SERVERS}
mkdir -p ${RUN_DIR} || exit

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

# Schedule the job 5 seconds from now, so we have time to copy configs
SLURM_JOB="$(sbatch -J $JOBNAME \
                    -t $TIMEOUT \
                    --mail-user=$EMAIL \
                    -N $NNODE \
                    -n $NCORE \
                    -p $PARTITION \
                    --begin=now+5 \
                    ${DST_DIR}/frontera/sbatch_me.txt)"

echo "$(printf '%80s\n' | tr ' ' =)
Running ${TESTCASE} with ${DAOS_SERVERS} servers and ${DAOS_CLIENTS} clients
${SLURM_JOB}" |& tee -a ${RES_DIR}/${TIMESTAMP}/job_list.txt

# Copy configs to the job directory
echo ""
SLURM_JOB_ID="${SLURM_JOB##* }"
mkdir -p "${RUN_DIR}/${SLURM_JOB_ID}"
cp ${DST_DIR}/frontera/daos_*.yml ${RUN_DIR}/${SLURM_JOB_ID}
cp ${DST_DIR}/frontera/env_daos ${RUN_DIR}/${SLURM_JOB_ID}/env_daos
cp ${DAOS_DIR}/../repo_info.txt ${RUN_DIR}/${SLURM_JOB_ID}/repo_info.txt

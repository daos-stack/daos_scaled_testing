#!/bin/bash

TIMESTAMP=$(date +%Y%m%d)

export PATH
export LD_LIBRARY_PATH
export EMAIL
export DAOS_DIR
export TESTCASE
export LOGS=${RES_DIR}/${TIMESTAMP}/${TESTCASE}
export RUN_DIR=${LOGS}/log_${NUM_SERVERS}
mkdir -p ${RUN_DIR} || exit

export NUM_SERVERS
export NUM_CLIENTS
export INFLIGHT
export XFER_SIZE
export BLOCK_SIZE
export PPC
export OMPI_TIMEOUT

pushd ${RUN_DIR}

# Get TACC usage status
/usr/local/etc/taccinfo > ${RUN_DIR}/tacc_usage_status.txt 2>&1

# Schedule the job 5 seconds from now, so we have time to copy configs
# ID-dependant params in sbatch_job.sh should match the corresponding values below
SLURM_JOB="$(sbatch -J $JOBNAME \
                    -t $TIMEOUT \
                    --mail-user=$EMAIL \
                    -N $NNODE \
                    -n $NCORE \
                    -p $PARTITION \
                    --begin=now+5 \
                    ${DST_DIR}/frontera/sbatch_job.sh)"

echo "$(printf '%80s\n' | tr ' ' =)
Running ${TESTCASE} with ${NUM_SERVERS} servers and ${NUM_CLIENTS} clients
${SLURM_JOB}" |& tee -a ${RES_DIR}/${TIMESTAMP}/job_list.txt

# Create the job directory
echo ""
SLURM_JOB_ID="${SLURM_JOB##* }"
export JOB_DIR="${RUN_DIR}/${SLURM_JOB_ID}"
mkdir -p "${JOB_DIR}"

# If undefined, default to basic frontera configs
DAOS_AGENT_YAML="${DAOS_AGENT_YAML:-${DST_DIR}/frontera/configs/daos_agent_frontera.yml}"
DAOS_CONTROL_YAML="${DAOS_CONTROL_YAML:-${DST_DIR}/frontera/configs/daos_control_frontera.yml}"
DAOS_SERVER_YAML="${DAOS_SERVER_YAML:-${DST_DIR}/frontera/configs/daos_server_frontera.yml}"

# Copy each config to the job directory
cp "${DAOS_AGENT_YAML}" "${JOB_DIR}/daos_agent.yml"
cp "${DAOS_CONTROL_YAML}" "${JOB_DIR}/daos_control.yml"
cp "${DAOS_SERVER_YAML}" "${JOB_DIR}/daos_server.yml"

cp ${DST_DIR}/frontera/configs/test_env_frontera.sh ${JOB_DIR}/test_env.sh
cp ${DAOS_DIR}/../repo_info.txt ${JOB_DIR}/repo_info.txt

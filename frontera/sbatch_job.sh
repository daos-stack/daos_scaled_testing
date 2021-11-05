#!/bin/bash
#
# The sbatch job to run.
#

#SBATCH -o %j/output.txt        # Name of stdout output file
#SBATCH -e %j/output.txt        # Name of stderr error file
#SBATCH -A STAR-Intel           # Project Name
#SBATCH --mail-type=all         # Send email at begin and end of job

# Set ID-dependent params. These should match the corresponding values in run_sbatch.sh
export JOB_DIR="${RUN_DIR}/${SLURM_JOB_ID}"

export DAOS_AGENT_YAML="${JOB_DIR}/daos_agent.yml"
export DAOS_CONTROL_YAML="${JOB_DIR}/daos_control.yml"
export DAOS_SERVER_YAML="${JOB_DIR}/daos_server.yml"
export DUMP_DIR="${JOB_DIR}/core_dumps"

mkdir -p ${RUN_DIR}

# Generate MPI hostlist
export ALL_HOSTLIST_FILE="${JOB_DIR}/daos_all_hostlist"
export SERVER_HOSTLIST_FILE="${JOB_DIR}/daos_server_hostlist"
export CLIENT_HOSTLIST_FILE="${JOB_DIR}/daos_client_hostlist"
${DST_DIR}/frontera/mpi_gen_hostlist.sh ${MPI_TARGET} ${NUM_SERVERS} ${NUM_CLIENTS}
if [ $? -ne 0 ]; then
    echo "Failed to generate mpi hostlist"
    exit 1
fi

# Run the test
${DST_DIR}/frontera/tests.sh ${1}

exit ${PIPESTATUS[0]}

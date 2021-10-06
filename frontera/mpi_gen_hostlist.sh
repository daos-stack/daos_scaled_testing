#!/bin/bash
#
# Generate server and client hostlists from slurm nodes.
# Expects RUN_DIR, SLURM_JOB_ID, SLURM_JOB_NUM_NODES to be defined.
#

mpi_target=$1
num_servers=$2
num_clients=$3

if [ "${mpi_target}" == "mvapich2" ] || [ "${mpi_target}" == "mpich" ]; then
    # Use abbreviated hostname
    srun -n $SLURM_JOB_NUM_NODES hostname | sed "/$(hostname)/d" | cut -c 1-8 > ${RUN_DIR}/${SLURM_JOB_ID}/daos_all_hostlist
elif [ "${mpi_target}" == "openmpi" ]; then
    # Use full hostname
    srun -n $SLURM_JOB_NUM_NODES hostname | sed "/$(hostname)/d" > ${RUN_DIR}/${SLURM_JOB_ID}/daos_all_hostlist
else
    echo "Unknown mpi_target. Please specify either mvapich2, openmpi, or mpich"
    exit 1
fi

# Split into server and client hostlists
cat ${RUN_DIR}/${SLURM_JOB_ID}/daos_all_hostlist | tail -$num_servers > ${RUN_DIR}/${SLURM_JOB_ID}/daos_server_hostlist
cat ${RUN_DIR}/${SLURM_JOB_ID}/daos_all_hostlist | head -$num_clients > ${RUN_DIR}/${SLURM_JOB_ID}/daos_client_hostlist

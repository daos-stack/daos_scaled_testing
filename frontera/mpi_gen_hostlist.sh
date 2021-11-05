#!/bin/bash
#
# Generate server and client hostlists from slurm nodes.
# Expected envrionement variables:
#   SLURM_JOB_NUM_NODES
#   ALL_HOSTLIST_FILE
#   SERVER_HOSTLIST_FILE
#   CLIENT_HOSTLIST_FILE
#

mpi_target=$1
num_servers=$2
num_clients=$3

if [ "${mpi_target}" == "mvapich2" ] || [ "${mpi_target}" == "mpich" ]; then
    # Use abbreviated hostname
    srun -n $SLURM_JOB_NUM_NODES hostname | sed "/$(hostname)/d" | cut -c 1-8 > "${ALL_HOSTLIST_FILE}"
elif [ "${mpi_target}" == "openmpi" ]; then
    # Use full hostname
    srun -n $SLURM_JOB_NUM_NODES hostname | sed "/$(hostname)/d" > "${ALL_HOSTLIST_FILE}"
else
    echo "Unknown mpi_target. Please specify either mvapich2, openmpi, or mpich"
    exit 1
fi

# Split into server and client hostlists
cat "${ALL_HOSTLIST_FILE}" | tail -$num_servers > "${SERVER_HOSTLIST_FILE}"
cat "${ALL_HOSTLIST_FILE}" | head -$num_clients > "${CLIENT_HOSTLIST_FILE}"

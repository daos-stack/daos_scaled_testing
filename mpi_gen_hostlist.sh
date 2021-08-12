#!/bin/bash

MPI_TARGET=$1
N_SERVERS=$2
N_CLIENTS=$3

if [ "${MPI_TARGET}" = "mvapich2" ] ||
   [ "${MPI_TARGET}" = "mpich" ]; then
    srun -n $SLURM_JOB_NUM_NODES hostname | sed "/$(hostname)/d" | cut -c 1-8 > ${RUN_DIR}/${SLURM_JOB_ID}/daos_all_hostlist
elif [ "${MPI_TARGET}" = "openmpi" ]; then
    srun -n $SLURM_JOB_NUM_NODES hostname > ${RUN_DIR}/${SLURM_JOB_ID}/daos_all_hostlist
    sed -i "/$(hostname)/d" ${RUN_DIR}/$SLURM_JOB_ID/daos_all_hostlist
else
    echo "Unknown MPI_TARGET. Please specify either mvapich2, openmpi, or mpich"
    exit 1
fi

cat ${RUN_DIR}/${SLURM_JOB_ID}/daos_all_hostlist | tail -$N_SERVERS > ${RUN_DIR}/${SLURM_JOB_ID}/daos_server_hostlist
cat ${RUN_DIR}/${SLURM_JOB_ID}/daos_all_hostlist | head -$N_CLIENTS > ${RUN_DIR}/${SLURM_JOB_ID}/daos_client_hostlist

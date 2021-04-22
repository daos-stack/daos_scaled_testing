#!/bin/bash

N_SERVERS=$1
N_CLIENTS=$2

srun -n $SLURM_JOB_NUM_NODES hostname | sed "/$(hostname)/d" | cut -c 1-8 > ${RUN_DIR}/${SLURM_JOB_ID}/daos_all_hostlist
cat ${RUN_DIR}/${SLURM_JOB_ID}/daos_all_hostlist | tail -$N_SERVERS > ${RUN_DIR}/${SLURM_JOB_ID}/daos_server_hostlist
cat ${RUN_DIR}/${SLURM_JOB_ID}/daos_all_hostlist | head -$N_CLIENTS > ${RUN_DIR}/${SLURM_JOB_ID}/daos_client_hostlist

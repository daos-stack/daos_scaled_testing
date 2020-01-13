#!/bin/bash

N_SERVERS=$1
N_CLIENTS=$2

srun -n $SLURM_JOB_NUM_NODES hostname > Log/$SLURM_JOB_ID/slurm_hostlist
sed -i "/$(hostname)/d" Log/$SLURM_JOB_ID/slurm_hostlist
cat Log/$SLURM_JOB_ID/slurm_hostlist | tail -$N_SERVERS > Log/$SLURM_JOB_ID/slurm_server_hostlist
sed 's/$/ slots=1/' Log/$SLURM_JOB_ID/slurm_server_hostlist > Log/$SLURM_JOB_ID/daos_server_hostlist
cat Log/$SLURM_JOB_ID/slurm_hostlist | head -$N_CLIENTS > Log/$SLURM_JOB_ID/daos_client_hostlist

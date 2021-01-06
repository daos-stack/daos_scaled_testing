#!/bin/bash

HOSTNAME=$(hostname)
TMP="$HOSTNAME"
cp -rfv /tmp/daos*log* ${RUN_DIR}/${SLURM_JOB_ID}/$1/${TMP}/ || true
dmesg > ${RUN_DIR}/${SLURM_JOB_ID}/$1/${TMP}/dmesg_output.txt
cat /var/log/messages > ${RUN_DIR}/${SLURM_JOB_ID}/$1/${TMP}/messages_output.txt
ls -la /sys/module/mlx5_core/parameters > ${RUN_DIR}/${SLURM_JOB_ID}/$1/${TMP}/mlx5_core_parameterstxt

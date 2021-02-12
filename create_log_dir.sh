#!/bin/bash

HOSTNAME=$(hostname)
TMP="$HOSTNAME"
mkdir -p ${RUN_DIR}/${SLURM_JOB_ID}/$1/${TMP}

pushd /tmp
rm -f daos_logs
ln -s ${RUN_DIR}/${SLURM_JOB_ID}/$1/${TMP} daos_logs
popd

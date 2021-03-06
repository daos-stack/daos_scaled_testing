#!/bin/bash

LOG_DIR=${RUN_DIR}/${SLURM_JOB_ID}/logs/$(hostname)

mkdir -p ${LOG_DIR}

pushd /tmp
rm -f daos_logs
ln -s ${LOG_DIR} daos_logs
popd

#!/bin/bash
#
# Create the DAOS log directory on a node.
#

LOG_DIR=${RUN_DIR}/${SLURM_JOB_ID}/logs/$(hostname)

mkdir -p ${LOG_DIR}

pushd /tmp > /dev/null
rm -f daos_logs
ln -s ${LOG_DIR} daos_logs
popd > /dev/null

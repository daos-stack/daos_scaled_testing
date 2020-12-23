#!/bin/bash

HOSTNAME=$(hostname)
TMP="$HOSTNAME"
cp -rfv /tmp/daos*log* ${RUN_DIR}/${SLURM_JOB_ID}/$1/${TMP}/ || true

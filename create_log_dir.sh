#!/bin/bash

HOSTNAME=$(hostname)
TMP="$HOSTNAME"
mkdir -p ${RUN_DIR}/${SLURM_JOB_ID}/$1/${TMP}

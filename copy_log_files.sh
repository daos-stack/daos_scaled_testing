#!/bin/bash

HOSTNAME=$(hostname)
TMP="$HOSTNAME"
dmesg > ${RUN_DIR}/${SLURM_JOB_ID}/$1/${TMP}/dmesg_output.txt

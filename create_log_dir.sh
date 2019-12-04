#!/bin/bash

HOSTNAME=$(hostname)
TMP="$HOSTNAME"
mkdir -p Log/$SLURM_JOB_ID/$1/$TMP

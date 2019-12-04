#!/bin/bash

HOSTNAME=$(hostname)
TMP="$HOSTNAME"
cp -rf /tmp/daos*log Log/$SLURM_JOB_ID/$1/$TMP/

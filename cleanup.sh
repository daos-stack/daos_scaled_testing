#!/bin/bash

rm -rf /dev/shm/*
rm -rf /tmp/daos*log

NUM_SERVERS=$(printf "%03d" $1)
mv Log/$SLURM_JOB_ID $LOGS/log-S$NUM_SERVERS-$SLURM_JOB_ID

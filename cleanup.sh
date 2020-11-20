#!/bin/bash

rm -rf /dev/shm/*
rm -rf /tmp/daos*log

mv -v Log/$SLURM_JOB_ID $LOGS/log_$1 || true

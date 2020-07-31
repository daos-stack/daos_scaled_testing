#!/bin/bash

rm -rf /dev/shm/*
rm -rf /tmp/daos*log

mv Log/$SLURM_JOB_ID $LOGS/log_$1

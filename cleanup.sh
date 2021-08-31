#!/bin/bash
#
# Cleanup to be run on each node after test execution
#

rm -rf /dev/shm/*
rm -rf /tmp/daos*log

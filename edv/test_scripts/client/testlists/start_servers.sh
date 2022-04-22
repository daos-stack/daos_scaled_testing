#!/bin/sh

export SCM="700G" #700G
export NVME="30T" #1T

export SRV_HEADNODE="edaos09"
export RUNDIR="/panfs/users/rpadma2/client"
export BUILDDIR="/panfs/users/schan15/builds"
export TB="daos_rel201rc1"
export NSERVER=2

${RUNDIR}/scripts/run_server.sh


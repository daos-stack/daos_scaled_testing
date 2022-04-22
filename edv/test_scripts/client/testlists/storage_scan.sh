#!/bin/sh

export RUNDIR="/panfs/users/schan15/client"
export MOUNTDIR="/tmp/daos"
export TB="daos_rc2"
export SRV_HOSTLIST="${RUNDIR}/../server/hostlists/srv_hostlist32.bak"
export CLI_HOSTLIST="${RUNDIR}/hostlists/cli_hostlist16"
. ${RUNDIR}/scripts/client_env.sh

dmg -o ${RUNDIR}/scripts/daos_control.yml -l edaos09,edaos10,edaos11,edaos12,edaos13,edaos14,edaos15,edaos16,edaos17,edaos18,edaos19,edaos20,edaos21,edaos22,edaos23,edaos24 storage scan
#dmg -o ${RUNDIR}/scripts/daos_control.yml -l edaos01,edaos02,edaos03,edaos04,edaos05,edaos06,edaos07,edaos08,edaos09,edaos10,edaos11,edaos12,edaos13,edaos14,edaos15,edaos16,edaos17,edaos18,edaos19,edaos20,edaos21,edaos22,edaos23,edaos24 storage scan

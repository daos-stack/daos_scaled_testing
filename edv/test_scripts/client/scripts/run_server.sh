#!/bin/sh

ps -ef | grep ${USER}

echo START time
date

export I_MPI_OFI_LIBRARY_INTERNAL=0
export I_MPI_OFI_PROVIDER="verbs;ofi_rxm"
export I_MPI_DEBUG=4

export SRV_HOSTLIST="${RUNDIR}/../server/hostlists/srv_hostlist${NSERVER}"
export CLI_HOSTLIST="${RUNDIR}/hostlists/cli_hostlist${NCLIENT}"

echo NPROCESS=${NPROCESS}

echo "Starting servers"
clush --user=daos_server -w ${SRV_HEADNODE} "export TB=${TB}; export NSERVER=${NSERVER}; cd ${RUNDIR}/../server; ./run_server.sh" 2>&1 &

sleep 660

clush -S --user=daos_server --hostfile=${SRV_HOSTLIST} "grep 'started on rank' /tmp/daos_control.log" 2>&1

if [[ $? -ne 0 ]]; then
  echo Server failed to start
  killall clush
  clush --user=daos_server --hostfile=${SRV_HOSTLIST} "pkill -9 daos; pkill -9 daos"
  ps -ef | grep TB= | grep ssh | kill -9 `awk '{print $2}'`
  exit 1
fi


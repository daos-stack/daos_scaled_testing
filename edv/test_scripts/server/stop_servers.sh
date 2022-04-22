#!/bin/sh

export SRVDIR="/panfs/users/rpadma2/server"
#export NSERVER="32"
export ALLHOST="hostlists/srv_hostlist32"
export HOSTLIST="hostlists/srv_hostlist${NSERVER}"
#export TB=REL20_APP_dev6_3b627e4

#. ${PWD}/srv_env.sh

cd ${SRVDIR}
pwd
clush --hostfile=${ALLHOST} "export TB=${TB}; export SRVDIR=${SRVDIR}; cd ${SRVDIR}; ./clean_server.sh; ./clean_server.sh"
sleep 15
echo "Clean - DONE"

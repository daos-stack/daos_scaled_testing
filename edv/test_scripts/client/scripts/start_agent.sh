#!/bin/sh

source ${RUNDIR}/scripts/client_env.sh
rm -rf ${DAOS_AGENT_DRPC_DIR}
mkdir -p ${DAOS_AGENT_DRPC_DIR}
rm -f daos_server.attach_info_tmp
export HWLOC_HIDE_ERRORS=1
daos_agent -o ${RUNDIR}/scripts/daos_agent-${USER}.yml &
rm -rf /tmp/daos_m/$USER
mkdir -p /tmp/daos_m/$USER

#!/bin/bash

source ${RUNDIR}/scripts/client_env.sh
pkill -9 daos
rm -rf ${DAOS_AGENT_DRPC_DIR}

#!/bin/bash

. srv_env.sh
echo
which daos_server
echo
daos_server -o ${SRVDIR}/daos_server.yml start --recreate-superblocks

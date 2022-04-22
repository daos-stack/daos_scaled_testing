#!/bin/bash

. srv_env.sh
which daos_server
pkill -9 daos
kill -9 daos
rm -rf /mnt/daos0/*
rm -rf /mnt/daos1/*
rm -rf /dev/hugepages/spdk*
rm -rf /tmp/daos_*
mkdir -p /tmp/daos_server
rm -f /tmp/daos_control.log /tmp/daos_io0.log /tmp/daos_io1.log /tmp/daos_metrics*.csv
daos_ssd -o ${SRVDIR}/daos_server.yml format --debug <<< yes

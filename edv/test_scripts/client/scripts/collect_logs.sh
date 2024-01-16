#!/bin/sh

# Collect logs from the DAOS clients and servers
# This script needs the following environment variables:
# RUNDIR, NSERVER, NCLIENT, RESULTDIR, TB

echo START collect logs
date

export SRV_HOSTLIST="${RUNDIR}/../server/hostlists/srv_hostlist${NSERVER}"
export CLI_HOSTLIST="${RUNDIR}/hostlists/cli_hostlist${NCLIENT}"

rm -rf ${RESULTDIR}/clientlogs
mkdir -p ${RESULTDIR}/clientlogs

echo
echo "Copying clientlogs"
echo

echo clush --hostfile=${CLI_HOSTLIST} "mkdir -p ${RESULTDIR}/clientlogs/\`hostname\`; cp /tmp/daos_agent-${USER}/daos_client.log ${RESULTDIR}/clientlogs/\`hostname\`/; dmesg > ${RESULTDIR}/clientlogs/\`hostname\`/client_dmesg.txt"

clush --hostfile=${CLI_HOSTLIST} "mkdir -p ${RESULTDIR}/clientlogs/\`hostname\`; cp /tmp/daos_agent-${USER}/daos_client.log ${RESULTDIR}/clientlogs/\`hostname\`/; dmesg > ${RESULTDIR}/clientlogs/\`hostname\`/client_dmesg.txt"

echo
echo "Copying serverlogs"
echo

rm -rf ${RESULTDIR}/serverlogs
mkdir -p ${RESULTDIR}/serverlogs
chmod 777 ${RESULTDIR}/serverlogs

echo "clush --user=daos_server --hostfile=${SRV_HOSTLIST} \"export TB=${TB}; cd ${RUNDIR}/../server; source srv_env.sh; daos_metrics -S 0 --csv > /tmp/daos_metrics_0.csv; daos_metrics -S 1 --csv > /tmp/daos_metrics_1.csv; dmesg > /tmp/daos_dmesg.txt\""

clush --user=daos_server --hostfile=${SRV_HOSTLIST} "export TB=${TB}; cd ${RUNDIR}/../server; source srv_env.sh; daos_metrics -S 0 --csv > /tmp/daos_metrics_0.csv; daos_metrics -S 1 --csv > /tmp/daos_metrics_1.csv; dmesg > /tmp/daos_dmesg.txt"

echo "clush --user=daos_server --hostfile=${SRV_HOSTLIST} \"mkdir -p ${RESULTDIR}/serverlogs/\`hostname\`; cp /tmp/daos_*.* ${RESULTDIR}/serverlogs/\`hostname\`/; chmod -R 777 ${RESULTDIR}/serverlogs/\`hostname\`/\""

clush --user=daos_server --hostfile=${SRV_HOSTLIST} "mkdir -p ${RESULTDIR}/serverlogs/\`hostname\`; cp /tmp/daos_*.* ${RESULTDIR}/serverlogs/\`hostname\`/; chmod -R 777 ${RESULTDIR}/serverlogs/\`hostname\`/"

echo END collect logs
date


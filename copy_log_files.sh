#!/bin/bash

NODE_TYPE="${1}"
LOG_DIR=${RUN_DIR}/${SLURM_JOB_ID}/logs/$(hostname)

echo "Copying logs from node $(hostname)"

case ${NODE_TYPE} in
    server)
    # Metrics in csv format
    timeout --signal SIGKILL 1m daos_metrics -i 1 --csv > ${LOG_DIR}/daos_metrics.csv 2>&1

    # Metrics in standard format
    #timeout --signal SIGKILL 1m daos_metrics -i 1 > ${LOG_DIR}/daos_metrics.txt 2>&1

    timeout --signal SIGKILL 1m dmesg > ${LOG_DIR}/dmesg_output.txt 2>&1
    ;;

    client)
    timeout --signal SIGKILL 1m dmesg > ${LOG_DIR}/dmesg_output.txt 2>&1
    ;;

    *)
    echo "Error: Invalid node type: ${NODE_TYPE}"
    exit 1
    ;;
esac

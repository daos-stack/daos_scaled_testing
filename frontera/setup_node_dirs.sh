#!/bin/bash
#
# Create necessary directories on each node.
#

set -e

LOG_DIR=$1
if [ -z "$LOG_DIR" ]; then
    echo "Usage: $(basename $0) <LOG_DIR>";
    exit 1
fi

NODE_LOG_DIR=${LOG_DIR}/$(hostname)

mkdir -p ${NODE_LOG_DIR}

rm -f /tmp/daos_logs
ln -s ${NODE_LOG_DIR} /tmp/daos_logs

rm -rf /tmp/daos_agent
rm -rf /tmp/daos_server
mkdir /tmp/daos_agent
mkdir /tmp/daos_server

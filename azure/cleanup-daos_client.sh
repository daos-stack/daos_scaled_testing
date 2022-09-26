#!/bin/bash

# set -x
set -e
set -o pipefail
CWD="$(realpath "$(dirname $0)")"

source "$CWD/envs/env.sh"

echo  "[INFO] Clean up of DAOS clients"
$CLUSH_BIN $CLUSH_OPTS -w $CLIENT_NODES sudo systemctl stop daos_agent
$CLUSH_BIN $CLUSH_OPTS -w $CLIENT_NODES sudo rm -rf /tmp/daos_client.log /tmp/daos_admin.log /tmp/daos_agent.log

echo "[INFO] Stopping all DAOS processes"
$CLUSH_BIN $CLUSH_OPTS -w $CLIENT_NODES sudo 'bash -c "killall -q -9 orterun mpirun orted daos_agent || true"'

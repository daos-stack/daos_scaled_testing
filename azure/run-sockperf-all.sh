#!/bin/bash

# set -x
set -e
set -o pipefail

CWD="$(realpath "$(dirname $0)")"

echo
echo
echo "======================================================================================="
echo "Client Server"
time bash run-sockperf.sh daos-client-01 daos-server-01 | tee sockperf-client_server.log

echo
echo
echo "======================================================================================="
echo "Client Client"
time bash run-sockperf.sh daos-client-01 daos-client-02 | tee sockperf-client_client.log

echo
echo
echo "======================================================================================="
echo "Server Client"
time bash run-sockperf.sh daos-server-01 daos-client-01 | tee sockperf-server_client.log

echo
echo
echo "======================================================================================="
echo "Server Server"
time bash run-sockperf.sh daos-server-01 daos-server-02 | tee sockperf-server_server.log

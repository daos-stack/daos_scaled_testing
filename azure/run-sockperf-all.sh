#!/bin/bash

# set -x
set -e
set -o pipefail

CWD="$(realpath "$(dirname $0)")"

log_dir="$CWD/results/sockperf/$TIMESTAMP/"
mkdir -p "$log_dir"

echo
echo
echo "======================================================================================="
echo "Client Server"
time bash run-sockperf.sh daos-clie000001 daos-serv000001 | tee "$log_dir/sockperf-client_server.log"

echo
echo
echo "======================================================================================="
echo "Client Client"
time bash run-sockperf.sh daos-clie000001 daos-clie000002 | tee "$log_dir/sockperf-client_client.log"

echo
echo
echo "======================================================================================="
echo "Server Client"
time bash run-sockperf.sh daos-serv000001 daos-clie000001 | tee "$log_dir/sockperf-server_client.log"

echo
echo
echo "======================================================================================="
echo "Server Server"
time bash run-sockperf.sh daos-serv000001 daos-serv000002 | tee "$log_dir/sockperf-server_server.log"

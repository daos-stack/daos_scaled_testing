#!/bin/bash

# set -x
set -e
set -o pipefail

CWD="$(realpath "$(dirname $0)")"

bash plot-ntttcp.sh daos-serv000001 "daos-clie00000[1-8]" results/ntttcp/results-server_clients/ "[0:12000]"
mv -v dat/ntttcp-receiver.dat dat/ntttcp-server_clients-receiver.dat
mv -v dat/ntttcp-sender.dat dat/ntttcp-server_clients-sender.dat
mv -v png/ntttcp.png png/ntttcp-server_clients.png

bash plot-ntttcp.sh daos-clie000009 "daos-clie00000[1-8]" results/ntttcp/results-client_clients/ "[0:12000]"
mv -v dat/ntttcp-receiver.dat dat/ntttcp-client_clients-receiver.dat
mv -v dat/ntttcp-sender.dat dat/ntttcp-client_clients-sender.dat
mv -v png/ntttcp.png png/ntttcp-client_clients.png

bash plot-ntttcp.sh daos-clie000001 "daos-serv00000[1-8]" results/ntttcp/results-client_servers/ "[0:12000]"
mv -v dat/ntttcp-receiver.dat dat/ntttcp-client_servers-receiver.dat
mv -v dat/ntttcp-sender.dat dat/ntttcp-client_servers-sender.dat
mv -v png/ntttcp.png png/ntttcp-client_servers.png

bash plot-ntttcp.sh daos-serv000009 "daos-serv00000[1-8]" results/ntttcp/results-server_servers/ "[0:12000]"
mv -v dat/ntttcp-receiver.dat dat/ntttcp-server_servers-receiver.dat
mv -v dat/ntttcp-sender.dat dat/ntttcp-server_servers-sender.dat
mv -v png/ntttcp.png png/ntttcp-server_servers.png

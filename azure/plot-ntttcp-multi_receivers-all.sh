#!/bin/bash

# set -x
set -e
set -o pipefail

CWD="$(realpath "$(dirname $0)")"

bash plot-ntttcp-multi_receivers.sh "daos-clie00000[1-8]" daos-serv000001 results/ntttcp-multi_receivers/results-clients_server/ "[0:12000]"
mv -v dat/ntttcp-multi_receivers-receiver.dat dat/ntttcp-clients_server-receiver.dat
mv -v dat/ntttcp-multi_receivers-sender.dat dat/ntttcp-clients_server-sender.dat
mv -v png/ntttcp-multi_receivers.png png/ntttcp-clients_server.png

bash plot-ntttcp-multi_receivers.sh "daos-clie00000[1-8]" daos-clie000009 results/ntttcp-multi_receivers/results-clients_client/ "[0:12000]"
mv -v dat/ntttcp-multi_receivers-receiver.dat dat/ntttcp-clients_client-receiver.dat
mv -v dat/ntttcp-multi_receivers-sender.dat dat/ntttcp-clients_client-sender.dat
mv -v png/ntttcp-multi_receivers.png png/ntttcp-clients_client.png

bash plot-ntttcp-multi_receivers.sh "daos-serv00000[1-8]" daos-clie000001 results/ntttcp-multi_receivers/results-servers_client/ "[0:12000]"
mv -v dat/ntttcp-multi_receivers-receiver.dat dat/ntttcp-servers_client-receiver.dat
mv -v dat/ntttcp-multi_receivers-sender.dat dat/ntttcp-servers_client-sender.dat
mv -v png/ntttcp-multi_receivers.png png/ntttcp-servers_client.png

bash plot-ntttcp-multi_receivers.sh "daos-serv00000[1-8]" daos-serv000009 results/ntttcp-multi_receivers/results-servers_server/ "[0:12000]"
mv -v dat/ntttcp-multi_receivers-receiver.dat dat/ntttcp-servers_server-receiver.dat
mv -v dat/ntttcp-multi_receivers-sender.dat dat/ntttcp-servers_server-sender.dat
mv -v png/ntttcp-multi_receivers.png png/ntttcp-servers_server.png

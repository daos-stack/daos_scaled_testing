#!/bin/bash

set -e
set -o pipefail
CWD="$(realpath "$(dirname $0)")"

DAOS_NVME_ID="$(sudo lspci | grep "Non-Volatile memory controller" | cut -d" "  -f1 | head -n1)"

[[ -d /etc/daos ]]
if [[ -f /etc/daos/daos_server.yml ]]
then
	sudo mv -v /etc/daos/daos_server.yml /etc/daos/daos_server-$(date +%Y%m%d%H%M%S).yml.orig
fi

{
cat << EOF
name: daos_server
access_points:
  - daos-serv000000
port: 10001
provider: ofi+tcp;ofi_rxm
nr_hugepages: @DAOS_HUGEPAGES_NB@
control_log_mask: INFO
control_log_file: /tmp/daos_server.log
helper_log_file: /tmp/daos_admin.log
disable_vfio: true
telemetry_port: 9191

engines:
  - targets: 4
    nr_xs_helpers: 2
    fabric_iface: eth0
    fabric_iface_port: 31316
    log_mask: ERR
    log_file: /tmp/daos_engine_0.log
    env_vars:
      - DAOS_MD_CAP=1024
      - CRT_TIMEOUT=60
      - CRT_CREDIT_EP_CTX=0
    scm_mount: /mnt/daos0
    scm_class: ram
    scm_size: 50
    bdev_class: nvme
    bdev_list:
      - @DAOS_NVME_ID@

transport_config:
    allow_insecure: true
EOF
} | sed -E -e "s/@DAOS_HUGEPAGES_NB@/$DAOS_HUGEPAGES_NB/" -e "s/@DAOS_NVME_ID@/$DAOS_NVME_ID/" > /etc/daos/daos_server.yml

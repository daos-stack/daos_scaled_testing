#!/bin/bash

set -e
set -o pipefail
CWD="$(realpath "$(dirname $0)")"

DAOS_BDEV_CFG=${1?"Missing block device configuration (accepted value: 'single_bdev' and 'multi_bdevs')"}
if  ! [[ "$DAOS_BDEV_CFG" =~ ^(single_bdev|multi_bdevs)$ ]] ; then
	echo "[ERROR] Invalid DAOS block device configuration \"$DAOS_BDEV_CFG\": accepted mode are \"single_bdev\" and \"multi_bdevs\"" >&2
	exit 1
fi

DAOS_FIRST_NVME_ID="$(sudo lspci | grep "Non-Volatile memory controller" | cut -d" "  -f1 | sed -n -e 1p)"
DAOS_SECOND_NVME_ID="$(sudo lspci | grep "Non-Volatile memory controller" | cut -d" "  -f1 | sed -n -e 2p)"

[[ -d /etc/daos ]]
if [[ -f /etc/daos/daos_server.yml ]]
then
	sudo mkdir -p /etc/daos/backup
	sudo mv -v /etc/daos/daos_server.yml /etc/daos/backup/daos_server-$(date +%Y%m%d%H%M%S).yml
fi

{
	cat <<- EOF
	name: daos_server
	access_points:
	  - daos-serv000000
	port: 10001
	provider: ofi+tcp;ofi_rxm
	nr_hugepages: $DAOS_HUGEPAGES_NB
	control_log_mask: INFO
	control_log_file: /tmp/daos_server.log
	helper_log_file: /tmp/daos_admin.log
	disable_vfio: true
	telemetry_port: 9191

	transport_config:
	  allow_insecure: true

	engines:
	  - targets: 4
	    nr_xs_helpers: 2
	    pinned_numa_node: 0
	    fabric_iface: eth0
	    fabric_iface_port: 31316
	    # log_mask: INFO
	    log_mask: ERR
	    log_file: /tmp/daos_engine_0.log
	    env_vars:
	      - DAOS_MD_CAP=1024
	      - CRT_TIMEOUT=60
	      - CRT_CREDIT_EP_CTX=0
	    storage:
	      - class: ram
	        scm_mount: /mnt/daos0
	        scm_size: 50
	EOF

	case $DAOS_BDEV_CFG in
		single_bdev)
			cat <<- EOF
			      - class: nvme
			        bdev_list: ['$DAOS_FIRST_NVME_ID']
			EOF
			;;
		multi_bdevs)
			cat <<- EOF
			      - class: nvme
			        bdev_list: ['$DAOS_FIRST_NVME_ID']
			        bdev_roles: ['data']
			      - class: nvme
			        bdev_list: ['$DAOS_SECOND_NVME_ID']
			        bdev_roles: ['meta', 'wal']

			control_metadata:
			  path: /tmp/daos_server
			EOF
			;;
		*)
			echo "[ERROR] Invalid configuration"
			exit 1
			;;
	esac
} > /etc/daos/daos_server.yml

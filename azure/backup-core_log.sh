#!/bin/bash

# set -x
set -e -o pipefail

CWD="$(realpath "$(dirname $0)")"

source "$CWD/envs/env.sh"

BLOB_DIR="$HOME/backup/blobfuse-ckochhof"
if ! findmnt -t fuse -S blobfuse -M "$BLOB_DIR" ; then
	blobfuse $BLOB_DIR \
		--tmp-path=/mnt/blobfusetmp \
		--config-file=/home/azureuser/local/share/blobfuse/fuse_connection.cfg \
		 --use-adls=true \
		-o attr_timeout=240 \
		-o entry_timeout=240 \
		-o negative_timeout=120
fi

BACKUP_DIR="$BLOB_DIR/$TIMESTAMP"
for hostname in $(nodeset -e $SERVER_NODES) ; do
	mkdir -p "$BACKUP_DIR/cores/$hostname" "$BACKUP_DIR/logs/$hostname"
	echo "[INFO] Backup logs of server $hostname"
	scp $hostname:"/tmp/daos_*.log" "$BACKUP_DIR/logs/$hostname"
	echo "[INFO] Backup cores of server $hostname"
	ssh $hostname sudo tar -C /var/lib/systemd/coredump/ -c . | tar -C "$BACKUP_DIR/cores/$hostname" -xv
done

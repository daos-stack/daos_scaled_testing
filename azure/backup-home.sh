#!/bin/bash

# set -x
set -e -o pipefail

CWD="$(realpath "$(dirname $0)")"

BLOB_DIR="$HOME/backup/blobfuse-home"
BLOB_CFG="$HOME/local/share/blobfuse2/fuse_connection.yaml"
BLOB_CACHE_DIR="/mnt/blobfuse2tmp"

echo "[INFO] Creating cache dir $BLOB_CACHE_DIR"
sudo mkdir -p "$BLOB_CACHE_DIR"
sudo chown azureuser:azureuser "$BLOB_CACHE_DIR"

if ! findmnt -t fuse -S blobfuse2 -M "$BLOB_DIR" ; then
	echo "[INFO] Mounting endpoint $BLOB_DIR"
	blobfuse2 mount "$BLOB_DIR" --config-file="$BLOB_CFG"
fi

echo "[INFO] Archiving home"
rsync --archive --verbose --info=progress2 --human-readable --exclude .blobfuse2 --exclude .config --exclude .cache --exclude backup "$HOME/$dirname" "$HOME/backup/blobfuse-home"

echo "[INFO] Sync disks"
sync
sync

echo "[INFO] Unmounting endpoint $BLOB_DIR"
fusermount -u "$BLOB_DIR"

echo "[INFO] Backup is done"

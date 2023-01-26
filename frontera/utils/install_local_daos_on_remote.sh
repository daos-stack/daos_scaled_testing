#!/usr/bin/env bash
#
# Install local DAOS to remote nodes by copying and uncompressing an archive
# created with compress_daos_install.sh.
#
USAGE="Usage: install_local_daos_on_remote.sh <DAOS_DIR> <HOSTFILE>"

DAOS_DIR="$1"
HOSTFILE="$2"

function usage() {
    echo "$USAGE"
    exit 1
}

if [ -z "$DAOS_DIR" ] || [ -z "$HOSTFILE" ]; then
    usage
fi

if [ ! -d "${DAOS_DIR}/install" ]; then
    echo "Not a directory: ${DAOS_DIR}/install"
    usage
fi

if [ ! -f "$HOSTFILE" ]; then
    echo "File not found: $HOSTFILE"
    usage
fi

COMPRESSED_INSTALL="${DAOS_DIR}/install.tar.gz"
if [ ! -f "$COMPRESSED_INSTALL" ]; then
    # create it
    if [ $? -ne 0 ]; then
        echo "Failed to compress install: "$COMPRESSED_INSTALL""
        exit 1
    fi
fi


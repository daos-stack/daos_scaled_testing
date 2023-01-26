#!/usr/bin/env bash
#
# Compress a DAOS install path into a tar.gz
#
USAGE="Usage: compress_daos_install.sh <DAOS_DIR> <OUT_PATH>"

DAOS_DIR="$1"
OUT_PATH="$2"

function usage() {
    echo "$USAGE"
    exit 1
}

if [ -z "$DAOS_DIR" ] || [ -z "$OUT_PATH" ]; then
    usage
fi

if [ ! -d "${DAOS_DIR}/install" ]; then
    echo "Not a directory: ${DAOS_DIR}/install"
    usage
fi

OUT_PATH="$(realpath "$OUT_PATH")"

(
    cd "$DAOS_DIR" && 
    tar -cvzf "$OUT_PATH" \
        install/lib64/*.so* \
        install/lib64/*.a* \
        install/lib64/daos/API_VERSION \
        install/lib64/daos/VERSION \
        install/lib64/daos_srv/*.so* \
        install/bin/daos_metrics \
        install/bin/daos_engine \
        install/bin/daos \
        install/bin/daos_server \
        install/bin/daos_server_helper \
        install/bin/dmg \
        install/bin/cart_ctl \
        install/bin/self_test \
        install/bin/daos_agent \
        install/bin/crt_launch \
        install/prereq/*/*/lib/*.so* \
        install/prereq/*/*/lib/*.a* \
        install/prereq/*/*/bin
)


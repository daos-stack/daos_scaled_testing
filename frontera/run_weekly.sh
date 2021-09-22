#!/bin/sh

DST_DIR="$(realpath ../)" # Path to daos_scaled_testing repo

if [ ! -d "${DST_DIR}" ]; then
    echo "DST_DIR not found: ${DST_DIR}"
    exit 1
fi

${DST_DIR}/frontera/run_build.sh
if [ $? -ne 0 ]; then
  echo "Error: Failed to build artifacts"
  exit 1
fi

${DST_DIR}/frontera/run_testlist.py

#!/usr/bin/env bash

DST_DIR="$1"     # Path to daos_scaled_testing repo
BUILD_DIR="$2"   # DAOS build directory
DAOS_BRANCH="$3" # DAOS branch

if [ -z $DST_DIR ]; then
    DST_DIR="$(realpath ../../)"
fi
if [ -z $BUILD_DIR ]; then
    BUILD_DIR="${WORK}/BUILDS/weekly/master"
fi
if [ -z $DAOS_BRANCH ]; then
    DAOS_BRANCH="master"
fi

if [ ! -d "${DST_DIR}" ]; then
    echo "DST_DIR not found: ${DST_DIR}"
    exit 1
fi

${DST_DIR}/frontera/run_build.sh --build-dir "${BUILD_DIR}" --daos-branch "${DAOS_BRANCH}"
if [ $? -ne 0 ]; then
  echo "ERR: Failed to build"
  exit 1
fi

DAOS_DIR="${BUILD_DIR}/latest/daos"
echo ${DST_DIR}/frontera/run_testlist.py ${DST_DIR}/frontera/tests/basic -r --filter "daos_servers=8,daos_clients=32" --daos_dir="${DAOS_DIR}" --res_dir="${WORK}/RESULTS/weekly/20220307"
if [ $? -ne 0 ]; then
  echo "ERR: Failed to run tests"
  exit 1
fi

exit 0

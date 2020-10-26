#!/bin/sh

DST_DIR="<path_to_daos_scaled_testing>" #/scratch/TESTS/daos_scaled_testing

${DST_DIR}/run_build.sh
if [ $? -ne 0 ]; then
  echo "Error: Failed to build artifacts"
  exit 1
fi

${DST_DIR}/run_testlist.py

#!/bin/sh

SCRIPT_DIR="<path_to_daos_scaled_testing>" #/scratch/TESTS/daos_scaled_testing

${SCRIPT_DIR}/run_build.sh
if [ $? -ne 0 ]; then
  echo "Error: Failed to build artifacts"
  exit 1
fi

${SCRIPT_DIR}/run_testlist.py

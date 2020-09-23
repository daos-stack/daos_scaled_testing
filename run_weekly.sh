#!/bin/sh

DST_DIR="<path_to_daos_scaled_testing>" #/scratch/TESTS/daos_scaled_testing

$DST_DIR/run_build.sh
$DST_DIR/run_testlist.py

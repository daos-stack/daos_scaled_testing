#!/bin/bash
#
# Build DAOS locally, executed on a compute node.
#

JOBNAME="<sbatch_jobname>"
EMAIL="<email>" #<first.last@email.com>
export BUILD_DIR="<path_build_area>" #e.g./scratch/POC/BUILDS/
export DST_DIR="<path_to_daos_scaled_testing>" #/scratch/TESTS/daos_scaled_testing

mkdir -p ${BUILD_DIR}/slurm_logs
pushd ${BUILD_DIR}/slurm_logs
sbatch -J ${JOBNAME} -t 01:00:00 --mail-user=${EMAIL} -N 1 -n 32 -p normal ${DST_DIR}/run_build_sbatch.sh
popd


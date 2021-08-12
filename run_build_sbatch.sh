#!/bin/bash

#SBATCH -o stdout.o%j           # Name of stdout output file
#SBATCH -e stderr.e%j           # Name of stderr error file
#SBATCH -A STAR-Intel           # Project Name
#SBATCH --mail-type=all         # Send email at begin and end of job

${SCRIPT_DIR}/run_build.sh "-j32" |& tee build_output_${SLURM_JOB_ID}.txt

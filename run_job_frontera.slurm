#!/bin/bash
#
# Run a slurm job on Frontera

#SBATCH -o /dev/null           # Ignore stdout since all output is redirected
#SBATCH -e /dev/null           # ... and stderr
#SBATCH -A STAR-Intel          # Project Name
#SBATCH --mail-type=all        # Send email at begin and end of job

export JOB_ID="${SLURM_JOB_ID}"
export JOB_DIR="${RUN_DIR}/${JOB_ID}"

{
    mkdir -p ${JOB_DIR}

    if [ "${MPI_TARGET}" = "mvapich2" ] || [ "${MPI_TARGET}" = "mpich" ]; then
        srun -n ${SLURM_JOB_NUM_NODES} hostname | sed "/$(hostname)/d" | cut -c 1-8 > ${JOB_DIR}/hostlist_all
    elif [ "${MPI_TARGET}" = "openmpi" ]; then
        srun -n $SLURM_JOB_NUM_NODES hostname > ${RUN_DIR}/${SLURM_JOB_ID}/hostlist_all
        sed -i "/$(hostname)/d" ${RUN_DIR}/$SLURM_JOB_ID/hostlist_all
    else
        echo "Unknown MPI_TARGET. Please specify either mvapich2, openmpi, or mpich"
        exit 1
    fi

    cat ${JOB_DIR}/hostlist_all | tail -$DAOS_SERVERS > ${JOB_DIR}/hostlist_servers
    cat ${JOB_DIR}/hostlist_all | head -$DAOS_CLIENTS > ${JOB_DIR}/hostlist_clients

    ${SCRIPT_DIR}/tests.sh ${1}
} |& tee ${JOB_DIR}/output.txt

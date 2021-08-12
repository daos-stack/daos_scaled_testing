#!/bin/bash
#
# Run a single job based on the JOB_MANAGER

TIMESTAMP=$(date +%Y%m%d)

export PATH
export LD_LIBRARY_PATH
export EMAIL
export DAOS_DIR
export TESTCASE
export LOGS=${RES_DIR}/${TIMESTAMP}/${TESTCASE}
export RUN_DIR=${LOGS}/log_${DAOS_SERVERS}
mkdir -p ${RUN_DIR}

export DAOS_SERVERS
export DAOS_CLIENTS
export INFLIGHT
export XFER_SIZE
export BLOCK_SIZE
export PPC
export OMPI_TIMEOUT

# Generate a job id that is most likely unique
function gen_job_id() {
    date +%s%N
}

# Output each value in a comma-delimted string to a separate line in a file
function strlist_to_filelist() {
    local strlist="${1}"
    local filepath="${2}"
    local tmparray=""
    
    truncate --size 0 "${filepath}"
    
    IFS=','
    read -a tmparray <<< "${strlist}"
    for (( n=0; n < ${#tmparray[*]}; n++)) do
        echo "${tmparray[n]}" >> "${filepath}"
    done
}

pushd ${RUN_DIR}

# If on Frontera, get TACC usage status
if [ -f /usr/local/etc/taccinfo ]; then
    /usr/local/etc/taccinfo > ${RUN_DIR}/tacc_usage_status.txt 2>&1
fi

if [ -z "${JOB_MANAGER}" ]; then
    export JOB_MANAGER="NONE"
fi


# TODO possibly need support for "system". E.g. frontera, wolf
case "${JOB_MANAGER}" in
    SLURM)
        {
            SLURM_JOB="$(sbatch -J $JOBNAME -t $TIMEOUT --mail-user=$EMAIL -N $NNODE -n $NCORE -p $PARTITION ${SCRIPT_DIR}/run_job_frontera.slurm $TEST_GROUP)"
            printf '%80s\n' | tr ' ' =
            echo "Running ${TESTCASE} with ${DAOS_SERVERS} servers and ${DAOS_CLIENTS} clients"
            echo "${SLURM_JOB}"
        } |& tee -a ${RES_DIR}/${TIMESTAMP}/job_list.txt
        ;;
    NONE)
        #echo "JOB_MANAGER ${JOB_MANAGER} Not yet supported"
        #exit 1
        export JOB_ID="$(gen_job_id)"
        export JOB_DIR="${RUN_DIR}/${JOB_ID}"
        mkdir -p "${JOB_DIR}"
        {
            strlist_to_filelist "${HOSTNAMES_SERVERS}" ${JOB_DIR}/hostlist_servers
            strlist_to_filelist "${HOSTNAMES_CLIENTS}" ${JOB_DIR}/hostlist_clients
            cat ${JOB_DIR}/hostlist_servers > ${JOB_DIR}/hostlist_all
            cat ${JOB_DIR}/hostlist_clients >> ${JOB_DIR}/hostlist_all
            # TODO get this working
            #${SCRIPT_DIR}/tests.sh "${TEST_GROUP}"
        } |& tee ${JOB_DIR}/output.txt
        ;;
    *)
        echo "Unknown JOB_MANAGER ${JOB_MANAGER}"
esac

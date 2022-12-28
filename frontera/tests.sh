#!/bin/bash
# ----------------------------------------------------
# Run daos tests like IOR/MDtest and self_test(cart)
# ----------------------------------------------------

# Configurable parameters to be updated for each sbatch
DAOS_AGENT_DRPC_DIR="/tmp/daos_agent"
ACCESS_PORT=10001
OMPI_PARAM="--mca oob ^ud --mca btl self,tcp --mca pml ob1"

# Set undefined/default test params
NUMBER_OF_POOLS="${NUMBER_OF_POOLS:-1}"
[ ! -z ${DAOS_POOL_PROPS+x} ] || DAOS_POOL_PROPS=reclaim:disabled
NUM_PROCESSES=$(($DAOS_CLIENTS * $PPC))
CONT_PROP="${CONT_PROP:-dedup:memcmp}"
ITERATIONS="${ITERATIONS:-1}"
IOR_ITER_DELAY="${IOR_ITER_DELAY:-5}"
IOR_PHASE_DELAY="${IOR_PHASE_DELAY:-0}"
IOR_TREE_DEPTH="${IOR_TREE_DEPTH:-0}"

# Set common params/paths
SRUN_CMD="srun -n $SLURM_JOB_NUM_NODES -N $SLURM_JOB_NUM_NODES"
DAOS_SERVER_YAML="${RUN_DIR}/${SLURM_JOB_ID}/daos_server.yml"
DAOS_AGENT_YAML="${RUN_DIR}/${SLURM_JOB_ID}/daos_agent.yml"
DAOS_CONTROL_YAML="${RUN_DIR}/${SLURM_JOB_ID}/daos_control.yml"
SERVER_HOSTLIST_FILE="${RUN_DIR}/${SLURM_JOB_ID}/daos_server_hostlist"
ALL_HOSTLIST_FILE="${RUN_DIR}/${SLURM_JOB_ID}/daos_all_hostlist"
CLIENT_HOSTLIST_FILE="${RUN_DIR}/${SLURM_JOB_ID}/daos_client_hostlist"
DUMP_DIR="${RUN_DIR}/${SLURM_JOB_ID}/core_dumps"

# Time in seconds for openmpi timeout
OMPI_TIMEOUT="${OMPI_TIMEOUT:-300}"

# Time in seconds for clush timeout
CMD_TIMEOUT="${CMD_TIMEOUT:-300}"

# Time in seconds to wait for servers to start
SERVER_START_MAX_TIME="${SERVER_START_MAX_TIME:-300}"
SERVER_START_WAIT_TIME="${SERVER_START_WAIT_TIME:-15}"

# Time in seconds to wait for rebuild
REBUILD_KILL_WAIT_TIME="${REBUILD_KILL_WAIT_TIME:-5}"
REBUILD_MAX_TIME="${REBUILD_MAX_TIME:-600}"
REBUILD_WAIT_TIME="${REBUILD_WAIT_TIME:-30}"

# Set common MPI command
if [ "${MPI_TARGET}" == "mvapich2" ] || [ "${MPI_TARGET}" == "mpich" ]; then
    MPI_CMD="mpirun
             -np ${NUM_PROCESSES} -map-by node
             -hostfile ${CLIENT_HOSTLIST_FILE}"
elif [ "${MPI_TARGET}" == "openmpi" ]; then
    MPI_CMD="orterun ${OMPI_PARAM}
             -x CPATH -x PATH -x LD_LIBRARY_PATH
             -x FI_UNIVERSE_SIZE
             -x FI_OFI_RXM_USE_SRX
             -x D_LOG_FILE -x D_LOG_MASK
             --timeout ${OMPI_TIMEOUT} -np ${NUM_PROCESSES} --map-by node
             --hostfile ${CLIENT_HOSTLIST_FILE}"
else
    echo "Unknown MPI_TARGET. Please specify either mvapich2, openmpi, or mpich"
    exit 1
fi

if [ -z ${SW_TIME+x} ]; then
    IOR_SW_CMD=""
else
    IOR_SW_CMD="-O stoneWallingWearOut=1
                -O stoneWallingStatusFile=${RUN_DIR}/${SLURM_JOB_ID}/sw.ior
                -D ${SW_TIME}"
fi

# Print all relevant test params / env variables
echo "SLURM_JOB_ID    : ${SLURM_JOB_ID}"
echo "JOBNAME         : ${JOBNAME}"
echo "EMAIL           : ${EMAIL}"
echo "TEST_GROUP      : ${TEST_GROUP}"
echo "TESTCASE        : ${TESTCASE}"
echo "OCLASS          : ${OCLASS}"
echo "DIR_OCLASS      : ${DIR_OCLASS}"
echo "DAOS_SERVERS    : ${DAOS_SERVERS}"
echo "DAOS_CLIENTS    : ${DAOS_CLIENTS}"
echo "PPC             : ${PPC}"
echo "RANKS           : ${NUM_PROCESSES}"
echo "SEGMENTS        : ${SEGMENTS}"
echo "XFER_SIZE       : ${XFER_SIZE}"
echo "BLOCK_SIZE      : ${BLOCK_SIZE}"
echo "CONT_RF         : ${CONT_RF}"
echo "EC_CELL_SIZE    : ${EC_CELL_SIZE}"
echo "ITERATIONS      : ${ITERATIONS}"
echo "SW_TIME         : ${SW_TIME}"
echo "N_FILE          : ${N_FILE}"
echo "CHUNK_SIZE      : ${CHUNK_SIZE}"
echo "BYTES_READ      : ${BYTES_READ}"
echo "BYTES_WRITE     : ${BYTES_WRITE}"
echo "IOR_TREE_DEPTH  : ${IOR_TREE_DEPTH}"
echo "NUM_POOLS       : ${NUMBER_OF_POOLS}"
echo "POOL_SIZE       : ${POOL_SIZE}"
echo "FPP             : ${FPP}"
echo "MPI_TARGET      : ${MPI_TARGET}"
echo "IOR_PHASE_DELAY : ${IOR_PHASE_DELAY}"
echo "MDTEST_FLAGS    : ${MDTEST_FLAGS}"
echo
echo "Test runner hostname: ${HOSTNAME}"
echo

# Processes to be killed on teardown
PROCESSES="'(daos|orteun|mpirun)'"

# Time in milliseconds
CLOCK_DRIFT_THRESHOLD="${CLOCK_DRIFT_THRESHOLD:-500}"

# Set daos paths and libraries
function setup_daos_paths(){
    echo "DAOS_DIR:"
    echo "$(ls -ald $(realpath ${DAOS_DIR}/../.))"

    cat ${RUN_DIR}/${SLURM_JOB_ID}/repo_info.txt

    source ${DST_DIR}/frontera/build_env.sh ${MPI_TARGET}
    source ${RUN_DIR}/${SLURM_JOB_ID}/env_daos ${DAOS_DIR}

    export PATH=${DAOS_DIR}/install/ior_${MPI_TARGET}/bin:${PATH}
    export LD_LIBRARY_PATH=${DAOS_DIR}/install/ior_${MPI_TARGET}/lib:${LD_LIBRARY_PATH}

    echo PATH=$PATH
    echo
    echo LD_LIBRARY_PATH=$LD_LIBRARY_PATH
    echo

    module list
}

# Generate timestamp
function time_stamp(){
    date +%m/%d-%H:%M:%S
}

# Print a timestamped message
function pmsg(){
    echo
    echo "$(time_stamp) ${@}"
}

# Print a timestamped error message
function pmsg_err(){
    echo
    echo "$(time_stamp) ERR ${@}"
}

# Print a separator ======
function print_separator(){
    printf '%80s\n' | tr ' ' =
}

function collect_test_logs(){
    pmsg "Collecting metrics and logs"

    # Server nodes
    clush --hostfile ${SERVER_HOSTLIST_FILE} \
        --command_timeout ${CMD_TIMEOUT} --groupbase -S " \
        export PATH=${PATH}; export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}; \
        export RUN_DIR=${RUN_DIR}; export SLURM_JOB_ID=${SLURM_JOB_ID}; \
        ${DST_DIR}/frontera/copy_log_files.sh server "

    # Client nodes
    clush --hostfile ${CLIENT_HOSTLIST_FILE} \
        --command_timeout ${CMD_TIMEOUT} --groupbase -S " \
        export PATH=${PATH}; export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}; \
        export RUN_DIR=${RUN_DIR}; export SLURM_JOB_ID=${SLURM_JOB_ID}; \
        ${DST_DIR}/frontera/copy_log_files.sh client "
}

# Print command and run it, timestamp is prefixed
function run_cmd(){
    local cmd="$(echo ${1} | tr -s " ")"

    pmsg "CMD: ${cmd}"

    # Return output and return code in global vars
    OUTPUT_CMD="$(timeout --signal SIGKILL ${CMD_TIMEOUT} ${cmd})"
    RC=$?

    echo "${OUTPUT_CMD}"

    check_cmd_timeout "${RC}" "${cmd}"
}

function run_cmd_background(){
    local cmd="$(echo ${1} | tr -s " ")"

    pmsg "CMD: ${cmd}"

    # Put return code in global vars
    eval "${cmd}" &
    RC=$?
}

# Run a "daos" command on a client node
function run_daos_cmd(){
    local daos_cmd="$(echo ${1} | tr -s " ")"

    local client_node=$(head -n 1 ${CLIENT_HOSTLIST_FILE})

    local clush_cmd="clush
        -w ${client_node}
        --command_timeout ${CMD_TIMEOUT}
        -S
        -f ${SLURM_JOB_NUM_NODES} \"
        export PATH=$PATH;
        export LD_LIBRARY_PATH=$LD_LIBRARY_PATH;
        export CPATH=${CPATH};
        export DAOS_DISABLE_REQ_FWD=${DAOS_DISABLE_REQ_FWD};
        export DAOS_AGENT_DRPC_DIR=${DAOS_AGENT_DRPC_DIR};
        export D_LOG_FILE=${D_LOG_FILE};
        export D_LOG_MASK=${D_LOG_MASK};
        export FI_UNIVERSE_SIZE=${FI_UNIVERSE_SIZE};
        $daos_cmd\""

    pmsg "CMD: ${daos_cmd}"
    eval ${clush_cmd}

    return $?
}

# Run a "dmg" command on a client node
function run_dmg_cmd(){
    local dmg_cmd="$(echo ${1} | tr -s " ")"
    local teardown_on_error="${2:-true}"
    local quiet="${3:-false}"

    local client_node=$(head -n 1 ${CLIENT_HOSTLIST_FILE})

    local clush_cmd="clush
        -w ${client_node}
        --command_timeout ${CMD_TIMEOUT}
        -S \"
        export PATH=${PATH};
        export LD_LIBRARY_PATH=${LD_LIBRARY_PATH};
        ${dmg_cmd}\""

    pmsg "CMD: ${dmg_cmd}"

    # Return output and return code in global vars
    OUTPUT_CMD="$(eval ${clush_cmd})"
    RC=$?

    if ! ${quiet}; then
        echo "${OUTPUT_CMD}"
    fi

    check_cmd_timeout "${RC}" "${dmg_cmd}" "${teardown_on_error}"

    return $RC
}

# Run dmg pool create
function dmg_pool_create(){
    local label="${1:-test_pool}"

    pmsg "Creating pool ${label}"

    local cmd="dmg -o ${DAOS_CONTROL_YAML} pool create
               --scm-size ${POOL_SIZE}
               --label ${label}"

    local props="$DAOS_POOL_PROPS"

    if [ ! -z $EC_CELL_SIZE ]; then
        if [ ! -z $props ]; then
            props+=","
        fi
        props+="ec_cell_sz:$EC_CELL_SIZE"
    fi

    if [ ! -z $props ]; then
        cmd+=" --properties=${props}"
    fi

    run_dmg_cmd "${cmd}"

    # Set global POOL_LABEL
    POOL_LABEL="$label"
}

function dmg_pool_create_multi(){
    pmsg "Creating ${NUMBER_OF_POOLS} pools"

    local n=1
    until [ ${n} -gt ${NUMBER_OF_POOLS} ]
    do
        dmg_pool_create "test_pool_${n}"
        n=$[${n} + 1]
    done

    pmsg "Done, ${NUMBER_OF_POOLS} were created"
    if [ ${NUMBER_OF_POOLS} -gt 1 ]; then
        dmg_pool_list
    fi
}

# Run dmg pool destroy
function dmg_pool_destroy(){
    local pool_label="${1:-test_pool}"
    local force="${2:-true}"

    local cmd="dmg -o ${DAOS_CONTROL_YAML} pool destroy ${pool_label}"

    if $force; then
        cmd+=" --force"
    fi

    run_dmg_cmd "${cmd}"
}

# Run dmg pool list
# Use --verbose (new option) if available, added in v1.3.104-tb
function dmg_pool_list(){
    if [ -z "${DMG_POOL_LIST}" ]; then
        DMG_POOL_LIST="dmg -o ${DAOS_CONTROL_YAML} pool list"
        run_dmg_cmd "${DMG_POOL_LIST} --help" true true
        if echo ${OUTPUT_CMD} | grep -qe "--verbose"; then
            DMG_POOL_LIST+=" --verbose --no-query"
        fi
    fi

    run_dmg_cmd "${DMG_POOL_LIST}"
}

# Run dmg pool query
function dmg_pool_query(){
    local pool="${1}"
    local teardown_on_error="${2}"

    local cmd="dmg -o ${DAOS_CONTROL_YAML} pool query ${pool}"

    run_dmg_cmd "${cmd}" "${teardown_on_error}"
}

# Run dmg system query
function dmg_system_query(){
    local teardown_on_error="${1}"

    local cmd="dmg -o ${DAOS_CONTROL_YAML} system query"

    run_dmg_cmd "${cmd}" "${teardown_on_cmd_error}"
}

function get_daos_status(){
    local teardown_on_error="${1:-true}"

    dmg_pool_list
    dmg_pool_query "${POOL_LABEL}"

    get_server_status ${DAOS_SERVERS} true ${teardown_on_error}
}

function teardown_test(){
    local exit_message="${1}"
    local exit_rc="${2:-0}"
    local csh_prefix="clush --hostfile ${ALL_HOSTLIST_FILE} \
                      -f ${SLURM_JOB_NUM_NODES}"

    if [ ${exit_rc} -eq 0 ]; then
        pmsg "${exit_message}"
    else
        pmsg_err "${exit_message}"
    fi

    pmsg "Starting teardown"

    collect_test_logs

    pmsg "List test processes to be killed"
    eval "${csh_prefix} -B \"pgrep -a ${PROCESSES}\""
    pmsg "Killing test processes"
    eval "${csh_prefix} \"pkill -e --signal SIGKILL ${PROCESSES}\""
    sleep 1
    pmsg "List surviving processes"
    eval "${csh_prefix} -B \"pgrep -a ${PROCESSES}\""

    pmsg "${DST_DIR}/frontera/cleanup_node.sh"
    ${SRUN_CMD} ${DST_DIR}/frontera/cleanup_node.sh

    pmsg "Removing empty core dumps"
    find ${DUMP_DIR} -type d -empty -print -delete 

    pkill -e --signal SIGKILL -P $$

    pmsg "End of teardown"

    echo "End Time: $(date)"
    echo "EXIT_MESSAGE : ${exit_message}"
    echo "EXIT_RC      : ${exit_rc}"
    exit ${exit_rc}
}

function check_clock_sync(){
    pmsg "Retrieving local time of each node"
    run_cmd "clush --hostfile ${ALL_HOSTLIST_FILE} \
        -f ${SLURM_JOB_NUM_NODES} \
        ${DST_DIR}/frontera/print_node_local_time.sh"

    pmsg "Review that clock drift is less than ${CLOCK_DRIFT_THRESHOLD} milliseconds"
    clush -S -b --hostfile ${ALL_HOSTLIST_FILE} \
          -f ${SLURM_JOB_NUM_NODES} --groupbase \
          "/bin/ntpstat -m ${CLOCK_DRIFT_THRESHOLD}"
    local rc=$?

    if [ ${rc} -ne 0 ]; then
        teardown_test "clock drift is too high" 1
    else
        pmsg "Clock drift test Pass"
    fi
}

function check_cmd_timeout(){
    local rc=${1}
    local cmd_name="${2}"
    local teardown_on_error="${3:-true}"

    if [ ${rc} -eq 137 ]; then
        teardown_test "STATUS: ${cmd_name} TIMEOUT" 1
    elif [ ${rc} -ne 0 ]; then
        echo "rc: ${rc}"
        if [ ${teardown_on_error} = true ]; then
            teardown_test "STATUS: ${cmd_name} FAIL" 1
        fi
    else
        pmsg "STATUS: ${cmd_name} SUCCESS"
    fi
}

# Check whether all servers are "joined".
# Returns 0 if all joined, 1 otherwise.
function get_server_status(){
    local num_servers=${1}
    local teardown_on_cmd_error="${2:-true}"
    local teardown_on_bad_state="${3:-true}"
    local target_servers=$((${num_servers} - 1))

    dmg_system_query "${teardown_on_cmd_error}"
    # Command failed, but we didn't teardown, so just return an error
    if [ ${RC} -ne 0 ]; then
        return 1
    fi

    if [ "${target_servers}" -eq 0 ]; then
        # Check if single server is joined
        if echo ${OUTPUT_CMD} | grep -q "0\s*Joined"; then
            return 0
        fi
    else
        # Check if exactly all servers are joined
        local num_joined=$(echo "${OUTPUT_CMD}" | sed -n 's/.*\[0-\([0-9]*\)\] Joined.*/\1/p')
        if [ "${num_joined}" = "${target_servers}" ]; then
            return 0
        fi
        echo "${num_joined} != ${target_servers}"
    fi

    # State wasn't all Joined, so check for bad states
    if [ ${teardown_on_bad_state} = true ]; then
        if echo ${OUTPUT_CMD} | grep -q "Excluded\|Errored"; then
            teardown_test "Bad dmg system state" 1
        fi
    fi

    # Something is wrong, but we didn't teardown, so just return an error
    return 1
}

#Wait for all the DAOS servers to start
function wait_for_servers_to_start(){
    local num_servers=${1}
    local start_s=${SECONDS}
    local elapsed_s=0
    local servers_running=false

    pmsg "Waiting for ${num_servers} daos_servers to start within ${SERVER_START_MAX_TIME} seconds"

    while true
    do
        sleep ${SERVER_START_WAIT_TIME}
        get_server_status ${num_servers} false true
        local rc=$?
        elapsed_s=$[${SECONDS} - ${start_s}]
        if [ ${rc} -eq 0 ]; then
            servers_running=true
            break
        fi
        if [ ${elapsed_s} -ge ${SERVER_START_MAX_TIME} ]; then
            break
        fi
        pmsg "Elapsed ${elapsed_s} seconds. Retrying in ${SERVER_START_WAIT_TIME} seconds..."
    done

    if ! $servers_running; then
        teardown_test "Failed to start ${num_servers} DAOS servers within ${SERVER_START_MAX_TIME} seconds" 1
    fi

    pmsg "Started ${num_servers} DAOS servers in ${elapsed_s} seconds"
}

#Create server/client hostfile.
function prepare(){
    # Create core dump and log directories
    mkdir -p ${DUMP_DIR}/{server,ior,mdtest,agent,self_test,cart}
    ${SRUN_CMD} ${DST_DIR}/frontera/setup_node_dirs.sh ${RUN_DIR}/${SLURM_JOB_ID}/logs

    # Generate MPI hostlist
    ${DST_DIR}/frontera/mpi_gen_hostlist.sh ${MPI_TARGET} ${DAOS_SERVERS} ${DAOS_CLIENTS}
    if [ $? -ne 0 ]; then
        teardown_test "Failed to generate mpi hostlist" 1
    fi

    # Use current LD_LIBRARY_PATH if DAOS was built with the full env
    grep "SCONS_ENV = 'full'" "${DAOS_DIR}/daos.conf"
    if [ $? -eq 0 ]; then
        # Uncomment
        sed -i -z 's/#  env_pass_through:\n#  - LD_LIBRARY_PATH/  env_pass_through:\n  - LD_LIBRARY_PATH/' $DAOS_SERVER_YAML
    else
        # Comment out
        sed -i -z 's/  env_pass_through:\n  - LD_LIBRARY_PATH/#  env_pass_through:\n#  - LD_LIBRARY_PATH/' $DAOS_SERVER_YAML
    fi


    # Use the first server as the access point
    ACCESS_POINT=`cat ${SERVER_HOSTLIST_FILE} | head -1 | grep -o -m 1 "^c[0-9\-]*"`
    sed -i "/^access_points/ c\access_points: ['$ACCESS_POINT:$ACCESS_PORT']" $DAOS_SERVER_YAML
    sed -i "/^access_points/ c\access_points: ['$ACCESS_POINT:$ACCESS_PORT']" $DAOS_AGENT_YAML
    sed -i "s/^\- .*/\- $ACCESS_POINT:$ACCESS_PORT/" ${DAOS_CONTROL_YAML}
}

#Start DAOS agent
function start_agent(){
    local daos_cmd="daos_agent -o $DAOS_AGENT_YAML -s /tmp/daos_agent"
    local cmd="clush --hostfile ${CLIENT_HOSTLIST_FILE}
        -f ${SLURM_JOB_NUM_NODES} \"
        pushd ${DUMP_DIR}/agent > /dev/null;
        ulimit -c unlimited;
        export PATH=${PATH};
        export LD_LIBRARY_PATH=${LD_LIBRARY_PATH};
        export CPATH=${CPATH};
        export DAOS_DISABLE_REQ_FWD=${DAOS_DISABLE_REQ_FWD};
        $daos_cmd\" "
    echo "CMD: ${daos_cmd}"
    echo
    eval $cmd &
    sleep 20
}

#Dump attach info
function dump_attach_info(){
    local cmd="daos_agent -i -o $DAOS_AGENT_YAML dump-attachinfo -o ${RUN_DIR}/${SLURM_JOB_ID}/daos_server.attach_info_tmp"
    echo "CMD: ${cmd}"
    echo
    eval $cmd &
    sleep 20
}

function query_pools_rebuild(){
    pmsg "Querying all pools for \"Rebuild done\""

    dmg_pool_list
    local all_pools="$(echo "${OUTPUT_CMD}" | grep -Eo -- "[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}")"
    local num_pools=$(echo "${all_pools}" | wc -l)
    echo

    echo "NUM_POOLS_AFTER_REBUILD : ${num_pools}"
    if [ -z "${all_pools}" ] ; then
        pmsg "Zero Pools found!!"
        return
    fi

    local n=1
    local num_rebuild_done=0
    until [ ${n} -gt ${num_pools} ]
    do
        print_separator
        pmsg "Querying pool ${n} of ${num_pools}"
        local current_pool=$(echo "${all_pools}" | head -${n} | tail -n 1)
        dmg_pool_query "${current_pool}"
        if echo "${OUTPUT_CMD}" | grep -qE "Rebuild\sdone"; then
            num_rebuild_done=$[${num_rebuild_done} + 1]
        else
            pmsg "Failed to rebuild pool ${current_pool}"
        fi
        n=$[${n} + 1]
    done

    pmsg "Done, ${num_pools} were queried"
    echo "NUM_POOLS_REBUILD_DONE : ${num_rebuild_done}"
}

# Run daos pool query
function daos_pool_query(){
    local pool="${1:-${POOL_LABEL}}"

    run_daos_cmd "daos pool query ${pool}"
    if [ $? -ne 0 ]; then
        teardown_test "daos pool query FAIL" 1
    fi
}

# Run daos cont create
function daos_cont_create(){
    local pool="${1:-${POOL_LABEL}}"
    local label="${2:-test_cont}"

    # Compatibility params
    if [ -z $_DAOS_CONT_CREATE_POS ]; then
        run_daos_cmd "daos cont create --help | grep -- '--pool'"
        if [ $? -ne 0 ]; then
            _DAOS_CONT_CREATE_POS=true
        else
            _DAOS_CONT_CREATE_POS=false
        fi
    fi

    # TODO - Use CONT_PROP for all container properties
    local props="$CONT_PROP"

    if [ ! -z $CONT_RF ]; then
        if [ ! -z $props ]; then
            props+=","
        fi
        props+="rf:$CONT_RF"
    fi

    if [ $_DAOS_CONT_CREATE_POS = true ]; then
        local daos_cmd="daos container create ${pool} ${label}
            --sys-name=daos_server
            --type=POSIX"
    else
        local daos_cmd="daos container create
            --pool=${pool}
            --label=${label}
            --sys-name=daos_server
            --type=POSIX"
    fi

    if [ ! -z $props ]; then
        daos_cmd+=" --properties=${props}"
    fi

    run_daos_cmd "${daos_cmd}"
    if [ $? -ne 0 ]; then
        teardown_test "daos container create FAIL" 1
    fi

    # Set global CONT_LABEL
    CONT_LABEL="${label}"
}

# Run daos cont query
function daos_cont_query(){
    local pool="${1:-${POOL_LABEL}}"
    local cont="${2:-${CONT_LABEL}}"

    # Compatibility params
    if [ -z $_DAOS_CONT_QUERY_POS ]; then
        run_daos_cmd "daos cont query --help | grep -- '--pool'"
        if [ $? -ne 0 ]; then
            _DAOS_CONT_QUERY_POS=true
        else
            _DAOS_CONT_QUERY_POS=false
        fi
    fi

    if [ $_DAOS_CONT_QUERY_POS = true ]; then
        run_daos_cmd "daos container query ${pool} ${cont}"
    else
        run_daos_cmd "daos container query --pool=${pool} --cont=${cont}"
    fi
    if [ $? -ne 0 ]; then
        teardown_test "daos container query FAIL" 1
    fi
}

#Start daos servers
function start_server(){
    pmsg "Starting server..."
    local daos_cmd="daos_server start -i -o $DAOS_SERVER_YAML --recreate-superblocks"
    local cmd="clush --hostfile ${SERVER_HOSTLIST_FILE}
        -f $SLURM_JOB_NUM_NODES \"
        pushd ${DUMP_DIR}/server > /dev/null;
        ulimit -c unlimited;
        export PATH=${PATH};
        export LD_LIBRARY_PATH=${LD_LIBRARY_PATH};
        export CPATH=${CPATH};
        export DAOS_DISABLE_REQ_FWD=${DAOS_DISABLE_REQ_FWD};
        $daos_cmd \" 2>&1 "

    pmsg "CMD: ${daos_cmd}"
    eval $cmd &

    if [ $? -ne 0 ]; then
        teardown_test "daos_server start FAILED" 1
    fi

    wait_for_servers_to_start "${DAOS_SERVERS}"
}

# Run IOR write and read
function run_ior(){
    run_ior_write false
    if [ ${IOR_PHASE_DELAY} -ne 0 ]; then
        local cmd="sleep ${IOR_PHASE_DELAY}"
        pmsg "${cmd}"
        eval "${cmd}"
    fi
    run_ior_read
}

# Run IOR write
function run_ior_write(){
    local check_write="${1:-true}"

    pmsg "Running IOR WRITE"

    local write_params="-w"
    if $check_write; then
        write_params+=" -W"
    fi
    local ior_wr_cmd="${IOR_BIN}
        -C -e -g -G 27 -k -Q 1 -v ${write_params} ${FPP}
        -a DFS
        -b ${BLOCK_SIZE}
        -i ${ITERATIONS}
        -s ${SEGMENTS}
        -o /testFile
        ${IOR_SW_CMD}
        -d ${IOR_ITER_DELAY}
        -t ${XFER_SIZE}
        --dfs.pool ${POOL_LABEL}
        --dfs.cont ${CONT_LABEL}
        --dfs.group daos_server
        --dfs.oclass ${OCLASS}
        --dfs.chunk_size ${CHUNK_SIZE}"

    local wr_cmd="${MPI_CMD} ${ior_wr_cmd}"

    echo ${wr_cmd}
    echo

    # Enable core dump creation
    pushd ${DUMP_DIR}/ior > /dev/null
    ulimit -c unlimited
    eval ${wr_cmd}
    local ior_rc=$?
    popd > /dev/null

    daos_cont_query
    get_daos_status

    if [ ${ior_rc} -ne 0 ]; then
        echo -e "ior_rc: ${ior_rc}\n"
        teardown_test "IOR WRITE FAIL" 1
    fi

    pmsg "IOR WRITE SUCCESS"
}

# Run IOR read
function run_ior_read(){
    local teardown_on_daos_status="${1:-true}"
    pmsg "Running IOR READ"

    local ior_rd_cmd="${IOR_BIN}
        -C -e -g -G 27 -k -Q 1 -v -r -R ${FPP}
        -a DFS
        -b ${BLOCK_SIZE}
        -i ${ITERATIONS}
        -s ${SEGMENTS}
        -o /testFile
        ${IOR_SW_CMD}
        -d ${IOR_ITER_DELAY}
        -t ${XFER_SIZE}
        --dfs.pool ${POOL_LABEL}
        --dfs.cont ${CONT_LABEL}
        --dfs.group daos_server
        --dfs.oclass ${OCLASS}
        --dfs.chunk_size ${CHUNK_SIZE}"

    local rd_cmd="${MPI_CMD} ${ior_rd_cmd}"

    echo ${rd_cmd}
    echo

    # Enable core dump creation
    pushd ${DUMP_DIR}/ior > /dev/null
    ulimit -c unlimited
    eval ${rd_cmd}
    local ior_rc=$?
    popd > /dev/null

    daos_cont_query
    get_daos_status "${teardown_on_daos_status}"

    if [ ${ior_rc} -ne 0 ]; then
        echo -e "ior_rc: ${ior_rc}\n"
        teardown_test "IOR READ FAIL" 1
    fi

    pmsg "IOR READ SUCCESS"
}

#Run cart self_test
function run_self_test(){
    pmsg "CMD: Starting CaRT self_test..."

    let last_srv_index=$(( ${DAOS_SERVERS}-1 ))

    local st_cmd="self_test
        --path ${RUN_DIR}/${SLURM_JOB_ID}
        --group-name daos_server --endpoint 0-${last_srv_index}:0
        --message-sizes 'b1048576',' b1048576 0','0 b1048576',' b1048576 i2048',' i2048 b1048576',' i2048',' i2048 0','0 i2048','0' 
        --max-inflight-rpcs $INFLIGHT --repetitions 100 -t -n"

    local mpich_cmd="mpirun --prepend-rank
        -np 1 -map-by node
        -hostfile ${CLIENT_HOSTLIST_FILE}
        $st_cmd"

    local openmpi_cmd="orterun $OMPI_PARAM 
        -x CPATH -x PATH -x LD_LIBRARY_PATH
        -x CRT_PHY_ADDR_STR -x OFI_DOMAIN -x OFI_INTERFACE
        -x FI_UNIVERSE_SIZE
        -x FI_OFI_RXM_USE_SRX
        --timeout $OMPI_TIMEOUT -np 1 --map-by node
        --hostfile ${CLIENT_HOSTLIST_FILE}
        $st_cmd"

    local cmd
    if [ "${MPI_TARGET}" == "mvapich2" ]; then
        cmd=$mpich_cmd
    elif [ "${MPI_TARGET}" == "mpich" ]; then
        cmd=$mpich_cmd
    else
        cmd=$openmpi_cmd
    fi

    echo $cmd
    echo

    # Enable core dump creation
    pushd ${DUMP_DIR}/self_test > /dev/null
    ulimit -c unlimited
    eval $cmd
    local cart_rc=$?
    popd > /dev/null

    if [ ${cart_rc} -ne 0 ]; then
        echo -e "cart_rc: ${cart_rc}\n"
        teardown_test "CART self_test FAIL" 1
    else
        pmsg "STATUS: CART self_test SUCCESS"
    fi
}

# Run cart test_group_np_srv
function run_cart_test_group_np_srv(){
    pmsg "Running CART test_group_np_srv"

    let last_srv_index=$(( ${DAOS_SERVERS}-1 ))
    local num_ctx=17
    let last_ctx_index=$(( ${num_ctx}-1  ))
    local test_dir=${DUMP_DIR}/cart

    pushd ${test_dir} > /dev/null
    ulimit -c unlimited

    # TODO mpich or openmpi
    # Start a crt_launch process for each "server"
    local server_cart_cmd="
        crt_launch
        -e ${DAOS_DIR}/install/lib/daos/TESTING/tests/test_group_np_srv
        --name selftest_srv_grp
        --cfg_path=${test_dir}
        -c ${num_ctx}"

    local server_mpich_cmd="
        mpirun
        -np ${DAOS_SERVERS}
        -map-by node
        -hostfile ${SERVER_HOSTLIST_FILE}
        ${server_cart_cmd}"

    run_cmd_background "${server_mpich_cmd}"

    # TODO more robust/deterministic
    sleep 30

    # Start a self_test process
    local client_cart_cmd="
        self_test
        --path ${test_dir}
        --group-name selftest_srv_grp
        --endpoint 0-${last_srv_index}:0-${last_ctx_index}
        -q
        --message-sizes \"b200000\" 
        --max-inflight-rpcs ${INFLIGHT}
        --repetitions 10000"

    # TODO execute on client or dont require client node for this test
    run_cmd "${client_cart_cmd}"
}

# Run mdtest create, stat, read, remove
function run_mdtest(){
    pmsg "CMD: Starting MDTEST..."

    local params="-F -P -G 27 -N 1 -d / -p 10 -Y -v ${MDTEST_FLAGS}"

    local mdtest_cmd="${MDTEST_BIN}
        ${params}
        -a DFS
        --dfs.pool ${POOL_LABEL}
        --dfs.cont ${CONT_LABEL}
        --dfs.group daos_server
        --dfs.chunk_size ${CHUNK_SIZE}
        --dfs.oclass ${OCLASS}
        --dfs.dir_oclass ${DIR_OCLASS}
        -i ${ITERATIONS}
        -W ${SW_TIME}
        -e ${BYTES_READ}
        -w ${BYTES_WRITE}
        -z ${IOR_TREE_DEPTH}
        -n ${N_FILE}
        -x ${RUN_DIR}/${SLURM_JOB_ID}/sw.mdt"

    if [ ${IOR_PHASE_DELAY} -ne 0 ]; then
        mdtest_cmd+=" --run-cmd-before-phase=\"sleep ${IOR_PHASE_DELAY}\""
    fi

    local cmd="${MPI_CMD} ${mdtest_cmd}"

    echo $cmd
    echo

    # Enable core dump creation
    pushd ${DUMP_DIR}/mdtest > /dev/null
    ulimit -c unlimited
    eval $cmd
    local mdtest_rc=$?
    popd > /dev/null

    daos_cont_query
    get_daos_status

    if [ ${mdtest_rc} -ne 0 ]; then
        echo -e "mdtest_rc: ${mdtest_rc}\n"
        teardown_test "MDTEST FAIL" 1
    else
        pmsg "STATUS: MDTEST SUCCESS"
    fi

}

# Get a random server name from the SERVER_HOSTLIST_FILE
# the "lucky" server name will never be the access point
function get_doom_server(){
    local max_retry_attempts=1000
    local access_point=$(cat ${SERVER_HOSTLIST_FILE} | head -1)
    local doomed_server

    n=1
    until [ ${n} -ge ${max_retry_attempts} ]
    do
        doomed_server=$(shuf -n 1 ${SERVER_HOSTLIST_FILE})

        if [ "${access_point}" != "${doomed_server}" ]; then
            break
        fi

        n=$[${n} + 1]
    done

    if [ ${n} -ge ${max_retry_attempts} ]; then
        teardown_test "failed to get random doomed server" 1
    fi

    echo ${doomed_server}
}

# Kill one DAOS server randomly selected from the SERVER_HOSTLIST_FILE
# And wait for rebuild to complete
function kill_random_server(){
    local doomed_server=$(get_doom_server)

    get_daos_status

    pmsg "Waiting to kill ${doomed_server} server in ${REBUILD_KILL_WAIT_TIME} seconds..."
    sleep ${REBUILD_KILL_WAIT_TIME}
    pmsg "Killing ${doomed_server} server"

    local csh_prefix="clush -w ${doomed_server} -S -f 1"

    pmsg "pgrep -a ${PROCESSES}"
    eval "${csh_prefix} -B \"pgrep -a ${PROCESSES}\""
    pmsg "${csh_prefix} \"pkill -e --signal SIGKILL ${PROCESSES}\""
    eval "${csh_prefix} \"pkill -e --signal SIGKILL ${PROCESSES}\""
    echo "Kill Time: $(date)"
    pmsg "pgrep -a ${PROCESSES}"
    eval "${csh_prefix} -B \"pgrep -a ${PROCESSES}\""

    pmsg "Killed ${doomed_server} server"

    local n=1
    local start_s=${SECONDS}
    local rebuild_done=false
    until [ $[${SECONDS} - ${start_s}] -ge ${REBUILD_MAX_TIME} ]
    do
        dmg_pool_query "${POOL_LABEL}" false

        if echo "${OUTPUT_CMD}" | grep -qE "Rebuild\sdone"; then
            rebuild_done=true
            break
        fi

        if echo "${OUTPUT_CMD}" | grep -qE "Rebuild\sfailed"; then
            teardown_test "Rebuild failed" 1
        fi

        pmsg "Attempt ${n} failed. Retrying in ${REBUILD_WAIT_TIME} seconds..."
        n=$[${n} + 1]
        sleep ${REBUILD_WAIT_TIME}
    done

    if [ ${rebuild_done} = false ]; then
        teardown_test "Failed to rebuild pool ${POOL_LABEL} within ${REBUILD_MAX_TIME} seconds" 1
    fi

    pmsg "Pool rebuild completed"
    if [ ${NUMBER_OF_POOLS} -gt 1 ]; then
        pmsg "Waiting for other pools to rebuild within 30s"
        sleep 30
        pmsg "end of waiting"
    fi

    query_pools_rebuild
}

function run_testcase(){
    local test_group=$1

    echo "###################"
    echo "RUN: ${TESTCASE}"
    echo "Start Time: $(date)"
    echo "###################"

    # Prepare Enviornment
    setup_daos_paths
    prepare

    # System sanity check
    check_clock_sync

    case ${test_group} in
        SWIM)
            # Swim stabilization test by checking server fault detection
            start_server
            dmg_pool_create_multi
            kill_random_server
            ;;
        SWIM_IOR)
            # Swim stabilization test by checking server fault detection
            start_server
            start_agent
            dmg_pool_create
            daos_cont_create
            daos_cont_query
            run_ior_write
            kill_random_server
            run_ior_read false
            ;;
        IOR)
            start_server
            start_agent
            dmg_pool_create
            daos_cont_create
            daos_cont_query
            run_ior
            ;;
        SELF_TEST)
            start_server
            dump_attach_info
            run_self_test
            ;;
        CART)
            run_cart_test_group_np_srv
            ;;
        MDTEST)
            start_server
            start_agent
            dmg_pool_create
            daos_cont_create
            daos_cont_query
            run_mdtest
            ;;
        *)
            echo "Unknown test: Please use IOR, SELF_TEST or MDTEST"
    esac

    pmsg "End of testcase ${TESTCASE}"
    teardown_test "Success!" 0
}

run_testcase $TEST_GROUP

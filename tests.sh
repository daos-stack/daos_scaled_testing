#!/bin/bash
#----------------------------------------------------
#Run daos tests like IOR/MDtest and self_test(cart)
#----------------------------------------------------

# Configurable parameters to be updated for each job
DAOS_AGENT_DRPC_DIR="/tmp/daos_agent"
ACCESS_PORT=10001
OMPI_PARAM="--mca oob ^ud --mca btl self,tcp --mca pml ob1"

if [ "${MPI_TARGET}" == "mvapich2" ] || [ "${MPI_TARGET}" == "mpich" ]; then
    MPI_CMD="mpirun
             -np ${no_of_ps} -map-by node
             -hostfile ${CLIENT_HOSTLIST_FILE}"
elif [ "${MPI_TARGET}" == "openmpi" ]; then
    MPI_CMD="orterun ${OMPI_PARAM}
             -x CPATH -x PATH -x LD_LIBRARY_PATH
             -x FI_UNIVERSE_SIZE
             -x D_LOG_FILE -x D_LOG_MASK
             --timeout ${OMPI_TIMEOUT} -np ${no_of_ps} --map-by node
             --hostfile ${CLIENT_HOSTLIST_FILE}"
else
    echo "Unknown MPI_TARGET. Please specify either mvapich2, openmpi, or mpich"
    exit 1
fi

# Set undefined/default test params
NUMBER_OF_POOLS="${NUMBER_OF_POOLS:-1}"
no_of_ps=$(($DAOS_CLIENTS * $PPC))
CONT_RF="${CONT_RF:-0}"
CONT_PROP="${CONT_PROP:---properties=dedup:memcmp}"

# Print all relevant test params / env variables
echo "JOB_MANAGER     : ${JOB_MANAGER}"
echo "JOB_ID          : ${JOB_ID}"
echo "JOB_DIR         : ${JOB_DIR}"
echo "TESTCASE        : ${TESTCASE}"
echo "OCLASS          : ${OCLASS}"
echo "DIR_OCLASS      : ${DIR_OCLASS}"
echo "DAOS_SERVERS    : ${DAOS_SERVERS}"
echo "DAOS_CLIENTS    : ${DAOS_CLIENTS}"
echo "PPC             : ${PPC}"
echo "RANKS           : ${no_of_ps}"
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
echo "TREE_DEPTH      : ${TREE_DEPTH}"
echo "NUM_POOLS       : ${NUMBER_OF_POOLS}"
echo "POOL_SIZE       : ${POOL_SIZE}"
echo "FPP             : ${FPP}"
echo "MPI_TARGET      : ${MPI_TARGET}"


# Unload modules that are not needed on Frontera
module unload impi pmix hwloc intel
module list

# Other parameters
NUM_NODES="$(( ${DAOS_SERVERS} + ${DAOS_CLIENTS} + 1))"
DAOS_SERVER_YAML="${JOB_DIR}/daos_server.yml"
DAOS_AGENT_YAML="${JOB_DIR}/daos_agent.yml"
DAOS_CONTROL_YAML="${JOB_DIR}/daos_control.yml"
ALL_HOSTLIST_FILE="${JOB_DIR}/hostlist_all"
SERVER_HOSTLIST_FILE="${JOB_DIR}/hostlist_servers"
CLIENT_HOSTLIST_FILE="${JOB_DIR}/hostlist_clients"
DUMP_DIR="${JOB_DIR}/core_dumps"


# Time to wait for servers to start
INITIAL_BRINGUP_WAIT_TIME=30s
BRINGUP_WAIT_TIME=15s
BRINGUP_RETRY_ATTEMPTS=12

# Time to wait for rebuild
REBUILD_WAIT_TIME=5s
REBUILD_MAX_TIME=600 # seconds

WAIT_TIME=30s
MAX_RETRY_ATTEMPTS=6
PROCESSES="'(daos|orteun|mpirun)'"

# Time in milliseconds
CLOCK_DRIFT_THRESHOLD=500

HOSTNAME=$(hostname)
echo "hostname:"
echo $HOSTNAME
echo
echo "DAOS_DIR:"
BUILD=`ls -ald $(realpath ${DAOS_DIR}/../.)`
echo $BUILD

# Copy the build info file
mkdir -p ${JOB_DIR}
cp -v ${DAOS_DIR}/../repo_info.txt ${JOB_DIR}/repo_info.txt
cat ${JOB_DIR}/repo_info.txt

source ${SCRIPT_DIR}/env_daos ${DAOS_DIR}
source ${SCRIPT_DIR}/build_env.sh ${MPI_TARGET}

export PATH=${DAOS_DIR}/install/ior_${MPI_TARGET}/bin:${PATH}
export LD_LIBRARY_PATH=${DAOS_DIR}/install/ior_${MPI_TARGET}/lib:${LD_LIBRARY_PATH}

echo PATH=$PATH
echo
echo LD_LIBRARY_PATH=$LD_LIBRARY_PATH
echo

# Generate timestamp
function time_stamp() {
    date +%m/%d-%H:%M:%S
}

# Print a timestamped message
function pmsg() {
    local message="$@"
    printf "\n%s %s\n" "$(time_stamp)" "${message}"
}

# Print a timestamped error message
function pmsg_err() {
    local message="$@"
    printf "\n%s ERR %s\n" "$(time_stamp)" "${message}"
}

# Print a separator ======
function print_separator() {
    printf '%80s\n' | tr ' ' =
}

# TODO verify this works
function cleanup(){
    pmsg "Removing temporary files"
    local cmd='
        rm -rf /dev/shm/* &&
        rm -rf /tmp/daos*log
    '
    run_cmd_on_all_nodes "${cmd}" false
    echo "End Time: $(date)"
}

# TODO verify this works
function collect_test_logs(){
    pmsg "Collecting metrics and logs"

    # Server nodes
    local server_cmd='
        LOG_DIR="${JOB_DIR}/logs/$(hostname)" &&
        echo "Copying logs from node $(hostname)" &&
        timeout --signal SIGKILL 1m daos_metrics -i 1 --csv > ${LOG_DIR}/daos_metrics.csv 2>&1 &&
        timeout --signal SIGKILL 1m dmesg > ${LOG_DIR}/dmesg_output.txt 2>&1
    '
    clush --hostfile "${SERVER_HOSTLIST_FILE}" \
          --command_timeout "${CMD_TIMEOUT}" --groupbase -S \
          " export PATH=${PATH}; \
            export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}; \ 
            export JOB_DIR=${JOB_DIR}; \
            ${server_cmd}"

    # Client nodes
    local client_cmd='
        LOG_DIR="${JOB_DIR}/logs/$(hostname)" &&
        echo "Copying logs from node $(hostname)" &&
        timeout --signal SIGKILL 1m dmesg > ${LOG_DIR}/dmesg_output.txt 2>&1
    '
    clush --hostfile ${CLIENT_HOSTLIST_FILE} \
          --command_timeout "${CMD_TIMEOUT}" --groupbase -S \
          " export PATH=${PATH}; \
            export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}; \
            export JOB_DIR=${JOB_DIR}; \
            ${client_cmd}"
}

# Print command and run it, timestamp is prefixed
function run_cmd(){
    local CMD="$(echo ${1} | tr -s " ")"

    pmsg "CMD: ${CMD}"

    OUTPUT_CMD="$(timeout --signal SIGKILL ${CMD_TIMEOUT} ${CMD})"
    RC=$?

    echo "${OUTPUT_CMD}"

    check_cmd_timeout "${RC}" "${CMD}"
}

# Run a command on a single client node
# exports PATH and LD_LIBRARY_PATH
function run_cmd_on_client() {
    local CMD="$(echo ${1} | tr -s " ")"
    local TEARDOWN_ON_ERROR="${2:-true}"
    local QUIET="${3:-false}"

    pmsg "CMD: ${CMD}"

    CLUSH_CMD="clush --hostfile ${CLIENT_HOSTLIST_FILE} --pick 1 --command_timeout ${CMD_TIMEOUT} -S \"
         export PATH=${PATH};
         export LD_LIBRARY_PATH=${LD_LIBRARY_PATH};
         ${CMD} \" "

    OUTPUT_CMD="$(eval ${CLUSH_CMD})"
    RC=$?

    if ! ${QUIET}; then
        echo "${OUTPUT_CMD}"
    fi

    check_cmd_timeout "${RC}" "${CMD}" "${TEARDOWN_ON_ERROR}"
}

# Run a command on all client nodes
# exports PATH and LD_LIBRARY_PATH
function run_cmd_on_all_clients() {
    local CMD="$(echo ${1} | tr -s " ")"
    local TEARDOWN_ON_ERROR="${2:-true}"
    local QUIET="${3:-false}"

    pmsg "CMD: ${CMD}"

    CLUSH_CMD="clush --hostfile ${CLIENT_HOSTLIST_FILE} -f ${DAOS_CLIENTS} --command_timeout ${CMD_TIMEOUT} -S \"
         export PATH=${PATH};
         export LD_LIBRARY_PATH=${LD_LIBRARY_PATH};
         ${CMD} \" "

    OUTPUT_CMD="$(eval ${CLUSH_CMD})"
    RC=$?

    if ! ${QUIET}; then
        echo "${OUTPUT_CMD}"
    fi

    check_cmd_timeout "${RC}" "${CMD}" "${TEARDOWN_ON_ERROR}"
}

# Run a command on all nodes
# exports PATH and LD_LIBRARY_PATH
function run_cmd_on_all_nodes() {
    local CMD="$(echo ${1} | tr -s " ")"
    local TEARDOWN_ON_ERROR="${2:-true}"
    local QUIET="${3:-false}"

    pmsg "CMD: ${CMD}"

    CLUSH_CMD="clush --hostfile ${ALL_HOSTLIST_FILE} -f ${NUM_NODES} --command_timeout ${CMD_TIMEOUT} -S \"
         export PATH=${PATH};
         export LD_LIBRARY_PATH=${LD_LIBRARY_PATH};
         ${CMD} \" "

    OUTPUT_CMD="$(eval ${CLUSH_CMD})"
    RC=$?

    if ! ${QUIET}; then
        echo "${OUTPUT_CMD}"
    fi

    check_cmd_timeout "${RC}" "${CMD}" "${TEARDOWN_ON_ERROR}"
}

# Run dmg pool create
function dmg_pool_create(){
    local POOL_LABEL="${1:-test_pool}"

    pmsg "Creating pool ${POOL_LABEL}"

    local cmd="dmg -o ${DAOS_CONTROL_YAML} pool create
               --scm-size ${POOL_SIZE}
               --label ${POOL_LABEL}
               --properties reclaim:disabled"

    run_cmd_on_client "${cmd}"

    POOL_UUID=$(echo "${OUTPUT_CMD}" | grep "UUID" | cut -d ':' -f 3 | sed 's/^[ \t]*//;s/[ \t]*$//')
    POOL_SVC=$(echo "${OUTPUT_CMD}" | grep "Service Ranks" | cut -d ':' -f 3 | sed 's/^[ \t]*//;s/[ \t]*$//' | sed 's/[][]//g')
    echo -e "\n====== POOL INFO ======"
    echo POOL_UUID: ${POOL_UUID}
    echo POOL_SVC : ${POOL_SVC}
}

function dmg_pool_create_multi(){
    pmsg "Creating ${NUMBER_OF_POOLS} pools"

    local n=1
    until [ ${n} -gt ${NUMBER_OF_POOLS} ]
    do
        pmsg "Creating pool ${n} of ${NUMBER_OF_POOLS}"
        dmg_pool_create "test_pool_${n}"
        n=$[${n} + 1]
    done

    pmsg "Done, ${NUMBER_OF_POOLS} were created"
    dmg_pool_list
}

# Run dmg pool list.
# Use --verbose (new option) if available, added in v1.3.104-tb
function dmg_pool_list(){
    if [ -z "${DMG_POOL_LIST}" ]; then
        DMG_POOL_LIST="dmg -o ${DAOS_CONTROL_YAML} pool list"
        run_cmd_on_client "${DMG_POOL_LIST} --help" true true
        if echo ${OUTPUT_CMD} | grep -qe "--verbose"; then
            DMG_POOL_LIST+=" --verbose --no-query"
        fi
    fi

    run_cmd_on_client "${DMG_POOL_LIST}"
}

# Run dmg pool query.
function dmg_pool_query(){
    local UUID="${1}"
    local TEARDOWN_ON_ERROR="${2}"

    local cmd="dmg -o ${DAOS_CONTROL_YAML} pool query
              ${UUID}"

    run_cmd_on_client "${cmd}" "${TEARDOWN_ON_ERROR}"
}

function get_daos_status(){
    local TEARDOWN_ON_ERROR="${1:-true}"

    dmg_pool_list
    dmg_pool_query "${POOL_UUID}"

    get_server_status ${DAOS_SERVERS} true
    RC=$?
    if [ ${TEARDOWN_ON_ERROR} = true ] && [ $RC -ne 0 ]; then
        teardown_test "Bad server status" 1
    fi
}

function teardown_test(){
    local exit_message="${1}"
    local exit_rc="${2:-0}"
    local CSH_PREFIX="clush --hostfile ${ALL_HOSTLIST_FILE} \
                      -f ${NUM_NODES}"

    if [ ${exit_rc} -eq 0 ]; then
        pmsg "${exit_message}"
    else
        pmsg_err "${exit_message}"
    fi

    pmsg "Starting teardown"

    collect_test_logs

    pmsg "List test processes to be killed"
    eval "${CSH_PREFIX} -B \"pgrep -a ${PROCESSES}\""
    pmsg "Killing test processes"
    eval "${CSH_PREFIX} \"pkill -e --signal SIGKILL ${PROCESSES}\""
    sleep 1
    pmsg "List surviving processes"
    eval "${CSH_PREFIX} -B \"pgrep -a ${PROCESSES}\""

    cleanup

    pkill -e --signal SIGKILL -P $$

    pmsg "End of teardown"

    echo "EXIT_MESSAGE : ${exit_message}"
    echo "EXIT_RC      : ${exit_rc}"
    exit ${exit_rc}
}

function check_clock_sync(){
    pmsg "Retrieving local time of each node"
    run_cmd "clush --hostfile ${ALL_HOSTLIST_FILE} \
                   -f ${NUM_NODES} \
                   ${SCRIPT_DIR}/print_node_local_time.sh"

    pmsg "Review that clock drift is less than ${CLOCK_DRIFT_THRESHOLD} milliseconds"
    clush -S --hostfile ${ALL_HOSTLIST_FILE} \
          -f ${NUM_NODES} --groupbase \
          "/bin/ntpstat -m ${CLOCK_DRIFT_THRESHOLD}"
    local RC=$?

    if [ ${RC} -ne 0 ]; then
        teardown_test "clock drift is too high" 1
    else
        pmsg "Clock drift test Pass"
    fi
}

function check_cmd_timeout(){
    local RC=${1}
    local CMD_NAME="${2}"
    local TEARDOWN_ON_ERROR="${3:-true}"

    if [ ${RC} -eq 137 ]; then
        teardown_test "STATUS: ${CMD_NAME} TIMEOUT" 1
    elif [ ${RC} -ne 0 ]; then
        echo "RC: ${RC}"
        if [ ${TEARDOWN_ON_ERROR} = true ]; then
            teardown_test "STATUS: ${CMD_NAME} FAIL" 1
        fi
    else
        pmsg "STATUS: ${CMD_NAME} SUCCESS"
    fi
}

# Check whether all servers are "joined".
# Returns 0 if all joined, 1 otherwise.
function get_server_status(){
    local NUM_SERVERS=${1}
    local TARGET_SERVERS=$((${NUM_SERVERS} - 1))
    local TEARDOWN_ON_ERROR="${2:-false}"

    run_cmd_on_client "dmg -o ${DAOS_CONTROL_YAML} system query" "${TEARDOWN_ON_ERROR}"
    if [ "${TARGET_SERVERS}" -eq 0 ]; then
        if echo ${OUTPUT_CMD} | grep -q "0\s*Joined"; then
            return 0
        fi
    else
        if echo ${OUTPUT_CMD} | grep -q "\[0\-${TARGET_SERVERS}\]\sJoined"; then
            return 0
        fi
    fi

    return 1
}

#Wait for all the DAOS servers to start
function wait_for_servers_to_start(){
    local NUM_SERVERS=${1}
    local TARGET_SERVERS=$((${NUM_SERVERS} - 1))

    pmsg "Waiting for ${NUM_SERVERS} daos_servers to start \
          (${INITIAL_BRINGUP_WAIT_TIME} seconds)"
    sleep ${INITIAL_BRINGUP_WAIT_TIME}

    n=1
    until [ ${n} -ge ${BRINGUP_RETRY_ATTEMPTS} ]
    do
        get_server_status ${NUM_SERVERS} false
        RC=$?
        if [ ${RC} -eq 0 ]; then
            break
        fi
        pmsg "Attempt ${n}/${BRINGUP_RETRY_ATTEMPTS} failed, retrying in ${BRINGUP_WAIT_TIME} seconds..."
        n=$[${n} + 1]
        sleep ${BRINGUP_WAIT_TIME}
    done

    if [ ${n} -ge ${BRINGUP_RETRY_ATTEMPTS} ]; then
        teardown_test "Failed to start all ${NUM_SERVERS} DAOS servers" 1
    fi

	pmsg "Done, ${NUM_SERVERS} DAOS servers are up and running"
}

# Create the log directory on each node
# TODO verify this works
function create_log_dir() {
    local cmd="JOB_DIR=${JOB_DIR}"'
        LOG_DIR=${JOB_DIR}/logs/$(hostname) &&
        mkdir -p ${LOG_DIR} &&
        pushd /tmp &&
        rm -f daos_logs &&
        ln -s ${LOG_DIR} daos_logs &&
        popd
    '
    run_cmd_on_all_nodes "${cmd}"
}

#Create server/client hostfile.
function prepare(){
    #Create the folder for server/client logs.
    mkdir -p ${JOB_DIR}
    mkdir -p ${DUMP_DIR}/{server,ior,mdtest,agent,self_test}
    cp -v ${SCRIPT_DIR}/daos_*.yml ${JOB_DIR}
    create_log_dir

    ACCESS_POINT=`cat ${SERVER_HOSTLIST_FILE} | head -1 | grep -o -m 1 "^c[0-9\-]*"`

    sed -i "/^access_points/ c\access_points: ['$ACCESS_POINT:$ACCESS_PORT']" $DAOS_SERVER_YAML
    sed -i "/^access_points/ c\access_points: ['$ACCESS_POINT:$ACCESS_PORT']" $DAOS_AGENT_YAML
    sed -i "s/^\- .*/\- $ACCESS_POINT:$ACCESS_PORT/" ${DAOS_CONTROL_YAML}

    # Create the daos_agent folder
    # TODO create only on the nodes that need each
    run_cmd_on_all_nodes "mkdir -p /tmp/daos_agent && mkdir -p /tmp/daos_server"
}

#Start DAOS agent
function start_agent(){
    echo -e "\nCMD: Starting agent...\n"
    daos_cmd="daos_agent -o $DAOS_AGENT_YAML -s /tmp/daos_agent"
    cmd="clush --hostfile ${CLIENT_HOSTLIST_FILE}
    -f ${NUM_NODES} \"
    pushd ${DUMP_DIR}/agent;
    ulimit -c unlimited;
    export PATH=${PATH};
    export LD_LIBRARY_PATH=${LD_LIBRARY_PATH};
    export CPATH=${CPATH};
    export DAOS_DISABLE_REQ_FWD=${DAOS_DISABLE_REQ_FWD};
    $daos_cmd\" "
    echo $daos_cmd
    echo
    eval $cmd &
    sleep 20
}

#Dump attach info
function dump_attach_info(){
    echo -e "\nCMD: Dump attach info file...\n"
    cmd="daos_agent -i -o $DAOS_AGENT_YAML dump-attachinfo -o ${JOB_DIR}/daos_server.attach_info_tmp"
    echo $cmd
    echo
    eval $cmd &
    sleep 20
}

function query_pools_rebuild(){
    pmsg "Querying all pools for \"Rebuild done\""

    dmg_pool_list
    local ALL_POOLS="$(echo "${OUTPUT_CMD}" | grep -Eo -- "[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}")"
    local NUMBER_OF_POOLS=$(echo "${ALL_POOLS}" | wc -l)
    echo

    echo "NUM_POOLS_AFTER_REBUILD : ${NUMBER_OF_POOLS}"
    if [ -z "${ALL_POOLS}" ] ; then
        pmsg "Zero Pools found!!"
        return
    fi

    local n=1
    local num_rebuild_done=0
    until [ ${n} -gt ${NUMBER_OF_POOLS} ]
    do
        print_separator
        pmsg "Querying pool ${n} of ${NUMBER_OF_POOLS}"
        local CURRENT_POOL=$(echo "${ALL_POOLS}" | head -${n} | tail -n 1)
        dmg_pool_query "${CURRENT_POOL}"
        if echo "${OUTPUT_CMD}" | grep -qE "Rebuild\sdone"; then
            num_rebuild_done=$[${num_rebuild_done} + 1]
        else
            pmsg "Failed to rebuild pool ${CURRENT_POOL}"
        fi
        n=$[${n} + 1]
    done

    pmsg "Done, ${NUMBER_OF_POOLS} were queried"
    echo "NUM_POOLS_REBUILD_DONE : ${num_rebuild_done}"
}

#Create Container
function create_container(){
    echo -e "\nCMD: Creating container\n"

    CONT_UUID=$(uuidgen)
    HOST=$(head -n 1 ${CLIENT_HOSTLIST_FILE})
    echo CONT_UUID = $CONT_UUID
    echo HOST ${HOST}

    #For EC test, set container RF based on number of parity
    if [ -z "$CONT_RF" ] || [ "$CONT_RF" == "0" ]; then
       echo "Daos container created with default RF=0"
    else
       echo "Daos container created with RF=$CONT_RF"
       CONT_PROP="$CONT_PROP,rf:$CONT_RF"
    fi

    #Set EC test with different cell size
    if [ -z "$EC_CELL_SIZE" ] || [ "$EC_CELL_SIZE" == '1048576' ] || [ "$EC_CELL_SIZE" == '1M' ]; then
       echo "Daos container created with default EC Cell size"
    else
       echo "Daos container created with EC Cell size=$EC_CELL_SIZE"
       CONT_PROP="$CONT_PROP,ec_cell:$EC_CELL_SIZE"
    fi

    daos_cmd="daos container create --pool=${POOL_UUID} --cont ${CONT_UUID}
              --sys-name=daos_server --type=POSIX ${CONT_PROP}"
    cmd="clush -w ${HOST} --command_timeout ${CMD_TIMEOUT} -S
    -f ${NUM_NODES} \"
    export PATH=$PATH; export LD_LIBRARY_PATH=$LD_LIBRARY_PATH;
    export CPATH=${CPATH};
    export DAOS_DISABLE_REQ_FWD=${DAOS_DISABLE_REQ_FWD};
    export DAOS_AGENT_DRPC_DIR=${DAOS_AGENT_DRPC_DIR};
    export D_LOG_FILE=${D_LOG_FILE}; export D_LOG_MASK=${D_LOG_MASK};
    export FI_UNIVERSE_SIZE=${FI_UNIVERSE_SIZE};
    $daos_cmd\""

    pmsg "CMD: ${daos_cmd}"
    eval ${cmd}

    if [ $? -ne 0 ]; then
        teardown_test "Daos container create FAIL" 1
    else
        pmsg "Daos container create SUCCESS"
    fi
}

#Query Container
function query_container(){
    echo -e "\nCMD: Query container\n"

    HOST=$(head -n 1 ${CLIENT_HOSTLIST_FILE})
    daos_cmd="daos container query --pool=${POOL_UUID} --cont=${CONT_UUID}"
    cmd="clush -w ${HOST} --command_timeout ${CMD_TIMEOUT} -S
    -f ${NUM_NODES} \"
    export PATH=$PATH; export LD_LIBRARY_PATH=$LD_LIBRARY_PATH;
    export CPATH=${CPATH};
    export DAOS_DISABLE_REQ_FWD=${DAOS_DISABLE_REQ_FWD};
    export DAOS_AGENT_DRPC_DIR=${DAOS_AGENT_DRPC_DIR};
    export D_LOG_FILE=${D_LOG_FILE}; export D_LOG_MASK=${D_LOG_MASK};
    export FI_UNIVERSE_SIZE=${FI_UNIVERSE_SIZE};
    $daos_cmd\""

    pmsg "CMD: ${daos_cmd}"
    eval ${cmd}

    if [ $? -ne 0 ]; then
        teardown_test "Daos container query FAIL" 1
    else
        pmsg "Daos container query SUCCESS"
    fi
}

#Start daos servers
function start_server(){
    echo -e "\nCMD: Starting server...\n"
    daos_cmd="daos_server start -i -o $DAOS_SERVER_YAML --recreate-superblocks"
    cmd="clush --hostfile ${SERVER_HOSTLIST_FILE}
    -f $NUM_NODES \"
    pushd ${DUMP_DIR}/server;
    ulimit -c unlimited;
    export PATH=${PATH}; export LD_LIBRARY_PATH=${LD_LIBRARY_PATH};
    export CPATH=${CPATH};
    export DAOS_DISABLE_REQ_FWD=${DAOS_DISABLE_REQ_FWD};
    $daos_cmd \" 2>&1 "

    pmsg "CMD: ${daos_cmd}"
    eval $cmd &

    # If the command is not still running, it must have failed
    sleep 2
    if ! (ps | grep $!); then
        teardown_test "daos_server start FAILED" 1
    fi

    wait_for_servers_to_start "${DAOS_SERVERS}"
}

#Run IOR
function run_ior(){
    echo -e "\nCMD: Starting IOR..."

    if [ -z ${SW_TIME+x} ]; then
        SW_CMD=""
    else
        SW_CMD="-O stoneWallingWearOut=1
                -O stoneWallingStatusFile=${JOB_DIR}/ior.sw
                -D ${SW_TIME}"
    fi

    run_ior_write
    run_ior_read
}

function run_ior_write(){
    IOR_WR_CMD="${IOR_BIN}
                -a DFS -b ${BLOCK_SIZE} -C -e -w -W -g -G 27 -k ${FPP}
                -i ${ITERATIONS} -s ${SEGMENTS} -o /testFile ${SW_CMD}
                -d 5 -t ${XFER_SIZE} --dfs.cont ${CONT_UUID}
                --dfs.group daos_server --dfs.pool ${POOL_UUID}
                --dfs.oclass ${OCLASS} --dfs.chunk_size ${CHUNK_SIZE} -v"

    wr_cmd="${MPI_CMD} ${IOR_WR_CMD}"

    echo ${wr_cmd}
    echo

    # Enable core dump creation
    pushd ${DUMP_DIR}/ior
    ulimit -c unlimited
    eval ${wr_cmd}
    local IOR_RC=$?
    popd

    query_container
    get_daos_status

    if [ ${IOR_RC} -ne 0 ]; then
        echo -e "IOR_RC: ${IOR_RC}\n"
        teardown_test "IOR WRITE FAIL" 1
    else
        echo -e "\nSTATUS: IOR WRITE SUCCESS\n"
    fi
}

function run_ior_read(){
    IOR_RD_CMD="${IOR_BIN}
               -a DFS -b ${BLOCK_SIZE} -C -Q 1 -e -r -R -g -G 27 -k ${FPP}
               -i ${ITERATIONS} -s ${SEGMENTS} -o /testFile ${SW_CMD}
               -d 5 -t ${XFER_SIZE} --dfs.cont ${CONT_UUID}
               --dfs.group daos_server --dfs.pool ${POOL_UUID}
               --dfs.oclass ${OCLASS} --dfs.chunk_size ${CHUNK_SIZE} -v"

    rd_cmd="${MPI_CMD} ${IOR_RD_CMD}"

    echo ${rd_cmd}
    echo

    # Enable core dump creation
    pushd ${DUMP_DIR}/ior
    ulimit -c unlimited
    eval ${rd_cmd}
    local IOR_RC=$?
    popd

    query_container
    get_daos_status

    if [ ${IOR_RC} -ne 0 ]; then
        echo -e "IOR_RC: ${IOR_RC}\n"
        teardown_test "IOR READ FAIL" 1
    else
        echo -e "\nSTATUS: IOR READ SUCCESS\n"
    fi
}

#Run cart self_test
function run_self_test(){
    echo -e "\nCMD: Starting CaRT self_test...\n"

    let last_srv_index=$(( ${DAOS_SERVERS}-1 ))

    st_cmd="self_test
        --path ${JOB_DIR}
        --group-name daos_server --endpoint 0-${last_srv_index}:0
        --message-sizes 'b1048576',' b1048576 0','0 b1048576',' b1048576 i2048',' i2048 b1048576',' i2048',' i2048 0','0 i2048','0' 
        --max-inflight-rpcs $INFLIGHT --repetitions 100 -t -n"

    mvapich2_cmd="mpirun --prepend-rank
        -np 1 -map-by node
        -hostfile ${CLIENT_HOSTLIST_FILE}
        $st_cmd"

    mpich_cmd="mpirun --prepend-rank
        -np 1 -map-by node
        -hostfile ${CLIENT_HOSTLIST_FILE}
        $st_cmd"

    openmpi_cmd="orterun $OMPI_PARAM 
        -x CPATH -x PATH -x LD_LIBRARY_PATH
        -x CRT_PHY_ADDR_STR -x OFI_DOMAIN -x OFI_INTERFACE
        -x FI_UNIVERSE_SIZE
        --timeout $OMPI_TIMEOUT -np 1 --map-by node
        --hostfile ${CLIENT_HOSTLIST_FILE}
        $st_cmd"

    if [ "${MPI_TARGET}" == "mvapich2" ]; then
        cmd=$mvapich2_cmd
    elif [ "${MPI_TARGET}" == "openmpi" ]; then
        cmd=$openmpi_cmd
    else
        cmd=$mpich_cmd
    fi

    echo $cmd
    echo

    # Enable core dump creation
    pushd ${DUMP_DIR}/self_test
    ulimit -c unlimited
    eval $cmd
    local CART_RC=$?
    popd

    if [ ${CART_RC} -ne 0 ]; then
        echo -e "CART_RC: ${CART_RC}\n"
        teardown_test "CART self_test FAIL" 1
    else
        echo -e "\nSTATUS: CART self_test SUCCESS\n"
    fi
}

function run_mdtest(){
    echo -e "\nCMD: Starting MDTEST...\n"
    echo

    mdtest_cmd="${MDTEST_BIN}
                -a DFS
                --dfs.pool ${POOL_UUID}
                --dfs.group daos_server
                --dfs.cont ${CONT_UUID}
                --dfs.chunk_size ${CHUNK_SIZE}
                --dfs.oclass ${OCLASS}
                --dfs.dir_oclass ${DIR_OCLASS}
                -L -p 10 -F -N 1 -P -d / -W ${SW_TIME}
                -e ${BYTES_READ} -w ${BYTES_WRITE} -z ${TREE_DEPTH}
                -n ${N_FILE} -x ${JOB_DIR}/mdtest.sw -v"

    cmd="${MPI_CMD} ${mdtest_cmd}"

    echo $cmd
    echo

    # Enable core dump creation
    pushd ${DUMP_DIR}/mdtest
    ulimit -c unlimited
    eval $cmd
    local MDTEST_RC=$?
    popd

    query_container
    get_daos_status

    if [ ${MDTEST_RC} -ne 0 ]; then
        echo -e "MDTEST_RC: ${MDTEST_RC}\n"
        teardown_test "MDTEST FAIL" 1
    else
        echo -e "\nSTATUS: MDTEST SUCCESS\n"
    fi

}

# Get a random server name from the SERVER_HOSTLIST_FILE
# the "lucky" server name will never be the access point
function get_doom_server(){
    local MAX_RETRY_ATTEMPTS=1000
    local ACESS_POINT=$(cat ${SERVER_HOSTLIST_FILE} | head -1)

    n=1
    until [ ${n} -ge ${MAX_RETRY_ATTEMPTS} ]
    do
        local DOOMED_SERVER=$(shuf -n 1 ${SERVER_HOSTLIST_FILE})

        if [ "${ACESS_POINT}" != "${DOOMED_SERVER}" ]; then
            break
        fi

        n=$[${n} + 1]
    done

    if [ ${n} -ge ${MAX_RETRY_ATTEMPTS} ]; then
        teardown_test "failed to get random doomed server" 1
    fi

    echo ${DOOMED_SERVER}
}

# Kill one DAOS server randomly selected from the SERVER_HOSTLIST_FILE
# And wait for rebuild to complete
function kill_random_server(){
    local DOOMED_SERVER=$(get_doom_server)

    get_daos_status

    pmsg "Waiting to kill ${DOOMED_SERVER} server in ${WAIT_TIME} seconds..."
    sleep ${WAIT_TIME}
    pmsg "Killing ${DOOMED_SERVER} server"

    local CSH_PREFIX="clush -w ${DOOMED_SERVER} -S -f 1"

    pmsg "pgrep -a ${PROCESSES}"
    eval "${CSH_PREFIX} -B \"pgrep -a ${PROCESSES}\""
    pmsg "${CSH_PREFIX} \"pkill -e --signal SIGKILL ${PROCESSES}\""
    eval "${CSH_PREFIX} \"pkill -e --signal SIGKILL ${PROCESSES}\""
    echo "Kill Time: $(date)"
    pmsg "pgrep -a ${PROCESSES}"
    eval "${CSH_PREFIX} -B \"pgrep -a ${PROCESSES}\""

    pmsg "Killed ${DOOMED_SERVER} server"

    n=1
    start_s=${SECONDS}
    rebuild_done=false
    until [ $[${SECONDS} - ${start_s}] -ge ${REBUILD_MAX_TIME} ]
    do
        dmg_pool_query "${POOL_UUID}" false true

        echo "${OUTPUT_CMD}"

        if echo "${OUTPUT_CMD}" | grep -qE "Rebuild\sdone"; then
            rebuild_done=true
            break
        fi

        pmsg "Attempt ${n} failed. Retrying in ${REBUILD_WAIT_TIME} seconds..."
        n=$[${n} + 1]
        sleep ${REBUILD_WAIT_TIME}
    done

    if [ ${rebuild_done} = false ]; then
        teardown_test "Failed to rebuild pool ${POOL_UUID} within ${REBUILD_MAX_TIME} seconds" 1
    fi

    pmsg "Pool rebuild completed"
    pmsg "Waiting for other pools to rebuild within 30s"
    sleep 30
    pmsg "end of waiting"

    query_pools_rebuild
}

function run_testcase(){
    local testcase=$1

    echo "###################"
    echo "RUN: ${TESTCASE}"
    echo "Start Time: $(date)"
    echo "###################"

    # Prepare Enviornment
    prepare
    # System sanity check
    check_clock_sync

    case ${testcase} in
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
            create_container
            query_container
            run_ior_write
            kill_random_server
            ;;
        IOR)
            start_server
            #start_agent
            #dmg_pool_create
            #create_container
            #query_container
            #run_ior
            ;;
        SELF_TEST)
            start_server
            dump_attach_info
            run_self_test
            ;;
        MDTEST)
            start_server
            start_agent
            dmg_pool_create
            create_container
            query_container
            run_mdtest
            ;;
        *)
            echo "Unknown test ${testcase}: Please use IOR, SELF_TEST or MDTEST"
    esac

    pmsg "End of testcase ${TESTCASE}"
    teardown_test "Success!" 0
}

run_testcase $1

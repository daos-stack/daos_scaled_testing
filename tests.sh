#!/bin/bash
#----------------------------------------------------
#Run daos tests like IOR/MDtest and self_test(cart)
#----------------------------------------------------

#Unload modules that are not needed on Frontera
module unload impi pmix hwloc
module list

#Parameter to be updated for each sbatch
DAOS_AGENT_DRPC_DIR="/tmp/daos_agent"
ACCESS_PORT=10001
MPI="openmpi" #supports openmpi or mpich
OMPI_PARAM="--mca oob ^ud --mca btl self,tcp --mca pml ob1"

if [ "$MPI" != "openmpi" ] && [ "$MPI" != "mpich" ]; then
    echo "Unknown MPI. Please specify either openmpi or mpich"
    exit 1
fi

#Others
SRUN_CMD="srun -n $SLURM_JOB_NUM_NODES -N $SLURM_JOB_NUM_NODES"
DAOS_SERVER_YAML="${RUN_DIR}/${SLURM_JOB_ID}/daos_server.yml"
DAOS_AGENT_YAML="${RUN_DIR}/${SLURM_JOB_ID}/daos_agent.yml"
DAOS_CONTROL_YAML="${RUN_DIR}/${SLURM_JOB_ID}/daos_control.yml"
SERVER_HOSTLIST_FILE="${RUN_DIR}/${SLURM_JOB_ID}/daos_server_hostlist"
ALL_HOSTLIST_FILE="${RUN_DIR}/${SLURM_JOB_ID}/daos_all_hostlist"
CLIENT_HOSTLIST_FILE="${RUN_DIR}/${SLURM_JOB_ID}/daos_client_hostlist"
DUMP_DIR="${RUN_DIR}/${SLURM_JOB_ID}/core_dumps"
INITIAL_BRINGUP_WAIT_TIME=60s
WAIT_TIME=30s
MAX_RETRY_ATTEMPTS=6
PROCESSES="'(daos|orteun|mpirun)'"

# Time in milliseconds
CLOCK_DRIFT_THRESHOLD=500

no_of_ps=$(($DAOS_CLIENTS * $PPC))
PREFIX_MPICH="mpirun
              -np ${no_of_ps} -map-by node
              -hostfile ${CLIENT_HOSTLIST_FILE}"

PREFIX_OPENMPI="orterun ${OMPI_PARAM}
                -x CPATH -x PATH -x LD_LIBRARY_PATH
                -x FI_UNIVERSE_SIZE
                -x D_LOG_FILE -x D_LOG_MASK
                --timeout ${OMPI_TIMEOUT} -np ${no_of_ps} --map-by node
                --hostfile ${CLIENT_HOSTLIST_FILE}"

HOSTNAME=$(hostname)
echo $HOSTNAME
echo
BUILD=`ls -al $DAOS_DIR/../../latest`
echo $BUILD

mkdir -p ${RUN_DIR}
cp -v ${DAOS_DIR}/../repo_info.txt ${RUN_DIR}

source ${DST_DIR}/env_daos ${DAOS_DIR}
source ${DST_DIR}/build_env.sh ${MPI}

export PATH=$DAOS_DIR/install/ior_$MPI/bin:$PATH
export LD_LIBRARY_PATH=$DAOS_DIR/install/ior_$MPI/lib:$LD_LIBRARY_PATH

echo PATH=$PATH
echo
echo LD_LIBRARY_PATH=$LD_LIBRARY_PATH
echo

echo DAOS_SERVERS=$DAOS_SERVERS

# Generate timestamp
function time_stamp(){
    date +%m/%d-%H:%M:%S
}

# Print message, timestap is prefixed
function pmsg(){
    echo
    echo "$(time_stamp) ${1}"
}

function cleanup(){
    pmsg "Removing temporary files"
    ${SRUN_CMD} ${DST_DIR}/cleanup.sh
    echo "End Time: $(date)"
}

function collect_test_logs(){
    pmsg "Collecting metrics and logs"

    # Server nodes
    clush --hostfile ${SERVER_HOSTLIST_FILE} \
    --command_timeout ${CMD_TIMEOUT} --groupbase -S " \
    export PATH=${PATH}; export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}; \
    export RUN_DIR=${RUN_DIR}; export SLURM_JOB_ID=${SLURM_JOB_ID}; \
    ${DST_DIR}/copy_log_files.sh server "

    # Client nodes
    clush --hostfile ${CLIENT_HOSTLIST_FILE} \
    --command_timeout ${CMD_TIMEOUT} --groupbase -S " \
    export PATH=${PATH}; export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}; \
    export RUN_DIR=${RUN_DIR}; export SLURM_JOB_ID=${SLURM_JOB_ID}; \
    ${DST_DIR}/copy_log_files.sh client "
}

# Print command and run it, timestap is prefixed
function run_cmd(){
    local CMD="$(echo ${1} | tr -s " ")"

    echo
    echo "$(time_stamp) CMD: ${CMD}"

    OUTPUT_CMD="$(timeout --signal SIGKILL ${CMD_TIMEOUT} ${CMD})"
    RC=$?

    echo "${OUTPUT_CMD}"

    check_cmd_timeout ${RC} ${CMD}
}

# Get a random client node name from the CLIENT_HOSTLIST_FILE and then
# run a command
function run_cmd_on_client(){
    local DAOS_CMD="$(echo ${1} | tr -s " ")"
    local HOST=$(shuf -n 1 ${CLIENT_HOSTLIST_FILE})

    echo
    echo "$(time_stamp) CMD: ${DAOS_CMD}"

    CMD="clush -w ${HOST} --command_timeout ${CMD_TIMEOUT} -S \"
         export PATH=${PATH};
         export LD_LIBRARY_PATH=${LD_LIBRARY_PATH};
         ${DAOS_CMD} \" "

    OUTPUT_CMD="$(eval ${CMD})"
    RC=$?

    echo "${OUTPUT_CMD}"

    check_cmd_timeout ${RC} ${DAOS_CMD}
}

function get_daos_status(){
    run_cmd_on_client "dmg -o ${DAOS_CONTROL_YAML} pool list"
    run_cmd_on_client "dmg -o ${DAOS_CONTROL_YAML} pool query --pool ${POOL_UUID}"
    run_cmd_on_client "dmg -o ${DAOS_CONTROL_YAML} system query"
}

function teardown_test(){
    local CSH_PREFIX="clush --hostfile ${ALL_HOSTLIST_FILE} \
                      -f ${SLURM_JOB_NUM_NODES}"
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

    exit 0
}

function check_clock_sync(){
    pmsg "Retrieving local time of each node"
    run_cmd "clush --hostfile ${ALL_HOSTLIST_FILE} \
                   -f ${SLURM_JOB_NUM_NODES} \
                   ${DST_DIR}/print_node_local_time.sh"

    pmsg "Review that clock drift is less than ${CLOCK_DRIFT_THRESHOLD} milliseconds"
    clush -S --hostfile ${ALL_HOSTLIST_FILE} \
          -f ${SLURM_JOB_NUM_NODES} --groupbase \
          "/bin/ntpstat -m ${CLOCK_DRIFT_THRESHOLD}"

    if [ $? -ne 0 ]; then
        pmsg "Error clock drift is too high"
        teardown_test
    else
        pmsg "Clock drift test Pass"
    fi
}

function check_cmd_timeout(){
    local RC=${1}
    local CMD_NAME="${2}"

    if [ ${RC} -eq 137 ]; then
        pmsg "STATUS: ${CMD_NAME} TIMEOUT"
        teardown_test
    elif [ ${RC} -ne 0 ]; then
        pmsg "STATUS: ${CMD_NAME} FAIL"
        echo "RC: ${RC}"
        teardown_test
    else
        pmsg "STATUS: ${CMD_NAME} SUCCESS"
    fi
}

#Wait for all the DAOS servers to start
function wait_for_servers_to_start(){
    TARGET_SERVERS=$((${1} - 1))

    if [ "${TARGET_SERVERS}" -eq 0 ]; then
        pmsg "Waiting for single daos_server to start (90 seconds)"
        sleep 90
        run_cmd_on_client "dmg -o ${DAOS_CONTROL_YAML} system query"
        return
    fi

    pmsg "Waiting for [0-${TARGET_SERVERS}] daos_servers to start \
          (${INITIAL_BRINGUP_WAIT_TIME} seconds)"
    sleep ${INITIAL_BRINGUP_WAIT_TIME}

    n=1
    until [ ${n} -ge ${MAX_RETRY_ATTEMPTS} ]
    do
        run_cmd_on_client "dmg -o ${DAOS_CONTROL_YAML} system query"

        if echo ${OUTPUT_CMD} | grep -q "\[0\-${TARGET_SERVERS}\]\sJoined"; then
            break
        fi
        pmsg "Attempt ${n} failed, retrying in ${WAIT_TIME} seconds..."
        n=$[${n} + 1]
        sleep ${WAIT_TIME}
    done

    if [ ${n} -ge ${MAX_RETRY_ATTEMPTS} ]; then
        pmsg "Failed to start all the DAOS servers"
        teardown_test
    fi

    pmsg "Done, ${TARGET_SERVERS} DAOS servers are up and running"
}

#Create server/client hostfile.
function prepare(){
    #Create the folder for server/client logs.
    mkdir -p ${RUN_DIR}/${SLURM_JOB_ID}
    mkdir -p ${DUMP_DIR}/{server,ior,mdtest,agent,self_test}
    cp -v ${DST_DIR}/daos_*.yml ${RUN_DIR}/${SLURM_JOB_ID}
    ${SRUN_CMD} ${DST_DIR}/create_log_dir.sh

    if [ $MPI == "openmpi" ]; then
        ${DST_DIR}/openmpi_gen_hostlist.sh ${DAOS_SERVERS} ${DAOS_CLIENTS}
    else
        ${DST_DIR}/mpich_gen_hostlist.sh ${DAOS_SERVERS} ${DAOS_CLIENTS}
    fi

    ACCESS_POINT=`cat ${SERVER_HOSTLIST_FILE} | head -1 | grep -o -m 1 "^c[0-9\-]*"`

    sed -i "/^access_points/ c\access_points: ['$ACCESS_POINT:$ACCESS_PORT']" $DAOS_SERVER_YAML
    sed -i "/^access_points/ c\access_points: ['$ACCESS_POINT:$ACCESS_PORT']" $DAOS_AGENT_YAML
    sed -i "s/^\- .*/\- $ACCESS_POINT:$ACCESS_PORT/" ${DAOS_CONTROL_YAML}

    #Create the daos_agent folder
    srun -n $SLURM_JOB_NUM_NODES mkdir  /tmp/daos_agent
    srun -n $SLURM_JOB_NUM_NODES mkdir  /tmp/daos_server
}

#Start DAOS agent
function start_agent(){
    echo -e "\nCMD: Starting agent...\n"
    daos_cmd="daos_agent -o $DAOS_AGENT_YAML -s /tmp/daos_agent"
    cmd="clush --hostfile ${CLIENT_HOSTLIST_FILE}
    -f ${SLURM_JOB_NUM_NODES} \"
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
    cmd="daos_agent -i -o $DAOS_AGENT_YAML dump-attachinfo -o ${RUN_DIR}/${SLURM_JOB_ID}/daos_server.attach_info_tmp"
    echo $cmd
    echo
    eval $cmd &
    sleep 20
}

#Create Pool
function create_pool(){
    pmsg "Creating pool"

    HOST=$(head -n 1 ${CLIENT_HOSTLIST_FILE})
    echo HOST ${HOST}
    dmg_cmd="dmg -o ${DAOS_CONTROL_YAML} pool create --scm-size ${POOL_SIZE}"
    cmd="clush -w ${HOST} --command_timeout ${POOL_CREATE_TIMEOUT} -S
        \"export PATH=${PATH}; export LD_LIBRARY_PATH=${LD_LIBRARY_PATH};
        ${dmg_cmd}\""

    pmsg "CMD: ${dmg_cmd}"
    DAOS_POOL="$(eval ${cmd})"
    RC=$?
    echo "${DAOS_POOL}"

    POOL_UUID=$(echo "${DAOS_POOL}" | grep "UUID" | cut -d ':' -f 3 | sed 's/^[ \t]*//;s/[ \t]*$//')
    POOL_SVC=$(echo "${DAOS_POOL}" | grep "Service Ranks" | cut -d ':' -f 3 | sed 's/^[ \t]*//;s/[ \t]*$//' | sed 's/[][]//g')
    echo -e "\n====== POOL INFO ======"
    echo POOL_UUID: ${POOL_UUID}
    echo POOL_SVC : ${POOL_SVC}

    if [ ${RC} -ne 0 ]; then
        echo "dmg pool create FAIL"
        teardown_test
    else
        echo "dmg pool create SUCCESS"
    fi

    sleep 10
}

function setup_pool(){
    pmsg "Pool set-prop"
    run_cmd_on_client "dmg pool set-prop --pool=${POOL_UUID} --name=reclaim --value=disabled -o ${DAOS_CONTROL_YAML}"

    if [ ${RC} -ne 0 ]; then
        echo "dmg pool set-prop FAIL"
        teardown_test
    else
        echo "dmg pool set-prop SUCCESS"
    fi

    sleep 10
}

#Create Container
function create_container(){
    echo -e "\nCMD: Creating container\n"

    CONT_UUID=$(uuidgen)
    HOST=$(head -n 1 ${CLIENT_HOSTLIST_FILE})
    echo CONT_UUID = $CONT_UUID
    echo HOST ${HOST}
    daos_cmd="daos container create --pool=${POOL_UUID} --cont ${CONT_UUID}
              --sys-name=daos_server --type=POSIX --properties=dedup:memcmp"
    cmd="clush -w ${HOST} --command_timeout ${CMD_TIMEOUT} -S
    -f ${SLURM_JOB_NUM_NODES} \"
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
        echo "Daos container create FAIL"
        teardown_test
    else
        echo "Daos container create SUCCESS"
    fi
}

#Query Container
function query_container(){
    echo -e "\nCMD: Query container\n"

    HOST=$(head -n 1 ${CLIENT_HOSTLIST_FILE})
    daos_cmd="daos container query --pool=${POOL_UUID} --cont=${CONT_UUID}"
    cmd="clush -w ${HOST} --command_timeout ${CMD_TIMEOUT} -S
    -f ${SLURM_JOB_NUM_NODES} \"
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
        echo "Daos container query FAIL"
        teardown_test
    else
        echo "Daos container query SUCCESS"
    fi
}

#Start daos servers
function start_server(){
    echo -e "\nCMD: Starting server...\n"
    daos_cmd="daos_server start -i -o $DAOS_SERVER_YAML --recreate-superblocks"
    cmd="clush --hostfile ${SERVER_HOSTLIST_FILE}
    -f $SLURM_JOB_NUM_NODES \"
    pushd ${DUMP_DIR}/server;
    ulimit -c unlimited;
    export PATH=${PATH}; export LD_LIBRARY_PATH=${LD_LIBRARY_PATH};
    export CPATH=${CPATH};
    export DAOS_DISABLE_REQ_FWD=${DAOS_DISABLE_REQ_FWD};
    $daos_cmd \" 2>&1 "
    echo $daos_cmd
    echo
    eval $cmd &

    wait_for_servers_to_start ${DAOS_SERVERS}
}

#Run IOR
function run_ior(){
    echo -e "\nCMD: Starting IOR..."

    if [ -z ${SW_TIME+x} ]; then
        SW_CMD=""
    else
        SW_CMD="-O stoneWallingWearOut=1
                -O stoneWallingStatusFile=${RUN_DIR}/sw.${SLURM_JOB_ID}
                -D ${SW_TIME}"
    fi

    run_ior_write
    run_ior_read
}

function run_ior_write(){
    module unload intel
    module list

    IOR_WR_CMD="${IOR_BIN}
                -a DFS -b ${BLOCK_SIZE} -C -e -w -W -g -G 27 -k
                -i ${ITERATIONS} -s ${SEGMENTS} -o /testFile ${SW_CMD}
                -d 5 -t ${XFER_SIZE} --dfs.cont ${CONT_UUID}
                --dfs.group daos_server --dfs.pool ${POOL_UUID}
                --dfs.oclass ${OCLASS} --dfs.chunk_size ${CHUNK_SIZE} -v"

    if [ "${MPI}" == "openmpi" ]; then
        wr_cmd="${PREFIX_OPENMPI} ${IOR_WR_CMD}"
    else
        wr_cmd="${PREFIX_MPICH} ${IOR_WR_CMD}"
    fi

    echo ${wr_cmd}
    echo

    # Enable core dump creation
    pushd ${DUMP_DIR}/ior
    ulimit -c unlimited
    eval ${wr_cmd}
    IOR_RC=$?
    popd

    module load intel
    module list

    if [ ${IOR_RC} -ne 0 ]; then
        echo -e "\nSTATUS: IOR WRITE FAIL\n"
        teardown_test
    else
        echo -e "\nSTATUS: IOR WRITE SUCCESS\n"
    fi

    query_container
    get_daos_status
}

function run_ior_read(){
    module unload intel
    module list

    IOR_RD_CMD="${IOR_BIN}
               -a DFS -b ${BLOCK_SIZE} -C -Q 1 -e -r -R -g -G 27 -k
               -i ${ITERATIONS} -s ${SEGMENTS} -o /testFile ${SW_CMD}
               -d 5 -t ${XFER_SIZE} --dfs.cont ${CONT_UUID}
               --dfs.group daos_server --dfs.pool ${POOL_UUID}
               --dfs.oclass ${OCLASS} --dfs.chunk_size ${CHUNK_SIZE} -v"

    if [ "${MPI}" == "openmpi" ]; then
        rd_cmd="${PREFIX_OPENMPI} ${IOR_RD_CMD}"
    else
        rd_cmd="${PREFIX_MPICH} ${IOR_RD_CMD}"
    fi

    echo ${rd_cmd}
    echo

    # Enable core dump creation
    pushd ${DUMP_DIR}/ior
    ulimit -c unlimited
    eval ${rd_cmd}
    IOR_RC=$?
    popd

    module load intel
    module list

    if [ ${IOR_RC} -ne 0 ]; then
        echo -e "\nSTATUS: IOR READ FAIL\n"
        teardown_test
    else
        echo -e "\nSTATUS: IOR READ SUCCESS\n"
    fi

    query_container
    get_daos_status
}

#Run cart self_test
function run_self_test(){
    echo -e "\nCMD: Starting CaRT self_test...\n"

    let last_srv_index=$(( ${DAOS_SERVERS}-1 ))

    st_cmd="self_test
        --path ${RUN_DIR}/${SLURM_JOB_ID}
        --group-name daos_server --endpoint 0-${last_srv_index}:0
        --message-sizes 'b1048576',' b1048576 0','0 b1048576',' b1048576 i2048',' i2048 b1048576',' i2048',' i2048 0','0 i2048','0' 
        --max-inflight-rpcs $INFLIGHT --repetitions 100 -t -n"

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

    if [ "$MPI" == "openmpi" ]; then
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
    popd

    if [ $? -ne 0 ]; then
        echo -e "\nSTATUS: CART self_test FAIL\n"
        teardown_test
    else
        echo -e "\nSTATUS: CART self_test SUCCESS\n"
    fi
}

function run_mdtest(){
    echo -e "\nCMD: Starting MDTEST...\n"
    module unload intel
    module list
    no_of_ps=$(($DAOS_CLIENTS * $PPC))
    echo

    CONT_UUID=$(uuidgen)

    mdtest_cmd="${MDTEST_BIN}
                -a DFS
                --dfs.pool ${POOL_UUID}
                --dfs.group daos_server
                --dfs.cont ${CONT_UUID}
                --dfs.chunk_size ${CHUNK_SIZE}
                --dfs.oclass ${OCLASS}
                -L -p 10 -F -N 1 -P -d / -W ${SW_TIME}
                -e ${BYTES_READ} -w ${BYTES_WRITE} -z ${TREE_DEPTH}
                -n ${N_FILE} -x ${RUN_DIR}/sw.${SLURM_JOB_ID} -v"

    if [ "${MPI}" == "openmpi" ]; then
        cmd="${PREFIX_OPENMPI} ${mdtest_cmd}"
    else
        cmd="${PREFIX_MPICH} ${mdtest_cmd}"
    fi

    echo $cmd
    echo

    # Enable core dump creation
    pushd ${DUMP_DIR}/mdtest
    ulimit -c unlimited
    eval $cmd
    MDTEST_RC=$?
    popd

    module load intel
    module list

    get_daos_status

    if [ ${MDTEST_RC} -ne 0 ]; then
        echo -e "\nSTATUS: MDTEST FAIL\n"
        teardown_test
    else
        echo -e "\nSTATUS: MDTEST SUCCESS\n"
    fi

    query_container
    get_daos_status
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
        pmsg "hostlist too small and we have really bad lucky"
        teardown_test
    fi

    echo ${DOOMED_SERVER}
}

# Kill one DAOS server randomly selected from the SERVER_HOSTLIST_FILE
function kill_random_server(){
    local DOOMED_SERVER=$(get_doom_server)
    local MAX_RETRY_ATTEMPTS=30

    get_daos_status

    pmsg "Waiting to kill ${DOOMED_SERVER} server in ${WAIT_TIME} seconds..."
    sleep ${WAIT_TIME}
    pmsg "Killing ${DOOMED_SERVER} server"
    run_cmd "ssh ${DOOMED_SERVER} \"pgrep -a ${PROCESSES}\""
    run_cmd "ssh ${DOOMED_SERVER} \"pkill -e --signal SIGKILL ${PROCESSES}\""
    run_cmd "ssh ${DOOMED_SERVER} \"pgrep -a ${PROCESSES}\""
    pmsg "Killed ${DOOMED_SERVER} server"

    n=1
    until [ ${n} -ge ${MAX_RETRY_ATTEMPTS} ]
    do
        get_daos_status

        if echo "${OUTPUT_CMD}" | grep -qE "^Rebuild\sdone"; then
            break
        fi

        pmsg "Attempt ${n} failed, retrying in 1 second..."
        n=$[${n} + 1]
        sleep 1
    done

    if [ ${n} -ge ${MAX_RETRY_ATTEMPTS} ]; then
        pmsg "Failed to rebuild pool ${POOL_UUID}"
        teardown_test
    fi

    pmsg "Pool rebuild completed"
}

function run_testcase(){
    echo "###################"
    echo "RUN: ${TESTCASE}"
    echo "Start Time: $(date)"
    echo "###################"

    # Prepare Enviornment
    prepare
    # System sanity check
    check_clock_sync

    case ${test} in
        SWIM)
            # Swim stabilization test by checking server fault detection
            start_server
            create_pool
            kill_random_server
            ;;
        IOR)
            start_server
            start_agent
            create_pool
            setup_pool
            create_container
            query_container
            run_ior
            ;;
        SELF_TEST)
            start_server
            dump_attach_info
            run_self_test
            ;;
        MDTEST)
            start_server
            start_agent
            create_pool
            setup_pool
            run_mdtest
            ;;
        *)
            echo "Unknown test: Please use IOR, SELF_TEST or MDTEST"
    esac

    pmsg "End of testscase ${TESTCASE}"
    teardown_test
}

test=$1

run_testcase

#!/bin/bash
#----------------------------------------------------
#Run daos tests like IOR/MDtest and self_test(cart)
#----------------------------------------------------

#SBATCH -o stdout.o%j           # Name of stdout output file
#SBATCH -e stderr.e%j           # Name of stderr error file
#SBATCH -A STAR-Intel           # Project Name
#SBATCH --mail-type=all         # Send email at begin and end of job

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
INITIAL_BRINGUP_WAIT_TIME=60s
WAIT_TIME=30s
MAX_RETRY_ATTEMPTS=6
PROCESSES="'(daos|orteun|mpirun)'"

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

cleanup(){
    mkdir -p ${RUN_DIR}/${SLURM_JOB_ID}/cleanup
    $SRUN_CMD ${DST_DIR}/copy_log_files.sh "cleanup"
    $SRUN_CMD ${DST_DIR}/cleanup.sh ${DAOS_SERVERS}
    echo "End Time: $(date)"
}

# Generate timestamp
function time_stamp(){
    date +%m/%d-%H:%M:%S
}

# Print message, timestap is prefixed
function pmsg(){
    echo
    echo "$(time_stamp) ${1}"
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

function get_daos_status(){
    run_cmd "dmg -o ${DAOS_CONTROL_YAML} pool list"
    run_cmd "dmg -o ${DAOS_CONTROL_YAML} pool query --pool ${POOL_UUID}"
    run_cmd "dmg -o ${DAOS_CONTROL_YAML} system query"
}

function teardown_test(){
    local CSH_PREFIX="clush --hostfile ${ALL_HOSTLIST_FILE} \
                      -f ${SLURM_JOB_NUM_NODES}"
    pmsg "Starting teardown"

    sleep 10
    eval "${CSH_PREFIX} -B \"pgrep -a ${PROCESSES}\""
    eval "${CSH_PREFIX} \"pkill -e --signal SIGKILL ${PROCESSES}\""
    eval "${CSH_PREFIX} -B \"pgrep -a ${PROCESSES}\""

    cleanup

    # wait for all the background commands
    wait

    pmsg "End of teardown"

    pkill -P $$

    exit 0
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

    pmsg "Waiting for [0-${TARGET_SERVERS}] daos_servers to start \
          (${INITIAL_BRINGUP_WAIT_TIME} seconds)"
    sleep ${INITIAL_BRINGUP_WAIT_TIME}

    n=1
    until [ ${n} -ge ${MAX_RETRY_ATTEMPTS} ]
    do
        run_cmd "dmg -o ${DAOS_CONTROL_YAML} system query"

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

    pmsg "Done, ${CURRENT_SERVERS_UP} DAOS servers are up and running"
}

#Create server/client hostfile.
prepare(){
    #Create the folder for server/client logs.
    mkdir -p ${RUN_DIR}/${SLURM_JOB_ID}
    cp -v ${DST_DIR}/daos_*.yml ${RUN_DIR}/${SLURM_JOB_ID}
    $SRUN_CMD ${DST_DIR}/create_log_dir.sh "cleanup"

    if [ $MPI == "openmpi" ]; then
        ${DST_DIR}/openmpi_gen_hostlist.sh ${DAOS_SERVERS} ${DAOS_CLIENTS}
    else
        ${DST_DIR}/mpich_gen_hostlist.sh ${DAOS_SERVERS} ${DAOS_CLIENTS}
    fi

    ACCESS_POINT=`cat ${SERVER_HOSTLIST_FILE} | head -1 | grep -o -m 1 "^c[0-9\-]*"`

    sed -i "/^access_points/ c\access_points: ['$ACCESS_POINT:$ACCESS_PORT']" $DAOS_SERVER_YAML
    sed -i "/^access_points/ c\access_points: ['$ACCESS_POINT:$ACCESS_PORT']" $DAOS_AGENT_YAML
    sed -i "s/^\- .*/\- $ACCESS_POINT:$ACCESS_PORT/" $DAOS_CONTROL_YAML

    #Create the daos_agent folder
    srun -n $SLURM_JOB_NUM_NODES mkdir  /tmp/daos_agent
    srun -n $SLURM_JOB_NUM_NODES mkdir  /tmp/daos_server
}

#Start DAOS agent
start_agent(){
    echo -e "\nCMD: Starting agent...\n"
    daos_cmd="daos_agent -o $DAOS_AGENT_YAML -s /tmp/daos_agent"
    cmd="clush --hostfile ${ALL_HOSTLIST_FILE}
    -f $SLURM_JOB_NUM_NODES \"
    export PATH=$PATH; export LD_LIBRARY_PATH=$LD_LIBRARY_PATH;
    export CPATH=$CPATH; export DAOS_DISABLE_REQ_FWD=1;
    $daos_cmd\" "
    echo $daos_cmd
    echo
    eval $cmd &
    sleep 20
}

#Dump attach info
dump_attach_info(){
    echo -e "\nCMD: Dump attach info file...\n"
    cmd="daos_agent -i -o $DAOS_AGENT_YAML dump-attachinfo -o ${RUN_DIR}/${SLURM_JOB_ID}/daos_server.attach_info_tmp"
    echo $cmd
    echo
    eval $cmd &
    sleep 20
}

#Create Pool
create_pool(){
    pmsg "Creating pool"

    cmd="dmg -o $DAOS_CONTROL_YAML pool create --scm-size $POOL_SIZE"
    echo $cmd
    echo
    DAOS_POOL="$(timeout --signal SIGKILL ${POOL_CREATE_TIMEOUT} ${cmd})"
    check_cmd_timeout $? "dmg pool create"
    echo "${DAOS_POOL}"

    POOL_UUID="$(grep -o "UUID: [A-Za-z0-9\-]*" <<< $DAOS_POOL | awk '{print $2}')"
    POOL_SVC="$(grep -o "Service replicas: [A-Za-z0-9\-]*" <<< $DAOS_POOL | awk '{print $3}')"
    echo -e "\n====== POOL INFO ======"
    echo POOL_UUID: $POOL_UUID
    echo POOL_SVC : $POOL_SVC
    sleep 10
}

setup_pool(){
    pmsg "Pool set-prop"
    run_cmd "dmg pool set-prop --pool=$POOL_UUID --name=reclaim --value=disabled -o $DAOS_CONTROL_YAML"

    sleep 10
}

#Create Container
create_container(){
    echo -e "\nCMD: Creating container\n"

    CONT_UUID=$(uuidgen)
    HOST=$(head -n 1 ${SERVER_HOSTLIST_FILE})
    echo CONT_UUID = $CONT_UUID
    echo HOST $HOST
    daos_cmd="daos cont create --pool=$POOL_UUID --svc=$POOL_SVC --cont $CONT_UUID --type=POSIX --properties=dedup:memcmp"
    cmd="clush -w $HOST --command_timeout ${CMD_TIMEOUT} -S
    -f $SLURM_JOB_NUM_NODES \"
    export PATH=$PATH; export LD_LIBRARY_PATH=$LD_LIBRARY_PATH;
    export CPATH=$CPATH; export DAOS_DISABLE_REQ_FWD=1;
    export DAOS_AGENT_DRPC_DIR=$DAOS_AGENT_DRPC_DIR;
    export D_LOG_FILE=${D_LOG_FILE}; export D_LOG_MASK=${D_LOG_MASK};
    export OFI_DOMAIN=${OFI_DOMAIN}; export OFI_INTERFACE=${OFI_INTERFACE};
    export FI_MR_CACHE_MAX_COUNT=${FI_MR_CACHE_MAX_COUNT};
    export FI_UNIVERSE_SIZE=${FI_UNIVERSE_SIZE};
    export FI_VERBS_PREFER_XRC=${FI_VERBS_PREFER_XRC};
    $daos_cmd\""

    echo $daos_cmd
    eval $cmd
    if [ $? -ne 0 ]; then
        echo "Daos container create FAIL"
        teardown_test
    else
        echo "Daos container create SUCCESS"
    fi

    daos_cmd="daos cont query --pool=$POOL_UUID --svc=$POOL_SVC --cont=$CONT_UUID"
    cmd="clush -w $HOST --command_timeout ${CMD_TIMEOUT} -S
    -f $SLURM_JOB_NUM_NODES \"
    export PATH=$PATH; export LD_LIBRARY_PATH=$LD_LIBRARY_PATH;
    export CPATH=$CPATH; export DAOS_DISABLE_REQ_FWD=1;
    export DAOS_AGENT_DRPC_DIR=$DAOS_AGENT_DRPC_DIR;
    export D_LOG_FILE=${D_LOG_FILE}; export D_LOG_MASK=${D_LOG_MASK};
    export OFI_DOMAIN=${OFI_DOMAIN}; export OFI_INTERFACE=${OFI_INTERFACE};
    export FI_MR_CACHE_MAX_COUNT=${FI_MR_CACHE_MAX_COUNT};
    export FI_UNIVERSE_SIZE=${FI_UNIVERSE_SIZE};
    export FI_VERBS_PREFER_XRC=${FI_VERBS_PREFER_XRC};
    $daos_cmd\""

    echo $daos_cmd
    eval $cmd
    if [ $? -ne 0 ]; then
        echo "Daos container query FAIL"
        teardown_test
    else
        echo "Daos container query SUCCESS"
    fi
}

#Start daos servers
start_server(){
    echo -e "\nCMD: Starting server...\n"
    daos_cmd="daos_server start -i -o $DAOS_SERVER_YAML --recreate-superblocks"
    cmd="clush --hostfile ${SERVER_HOSTLIST_FILE}
    -f $SLURM_JOB_NUM_NODES \"
    pushd ${RUN_DIR};
    ulimit -c unlimited;
    export PATH=$PATH; export LD_LIBRARY_PATH=$LD_LIBRARY_PATH;
    export CPATH=$CPATH; export DAOS_DISABLE_REQ_FWD=1;
    $daos_cmd \" 2>&1 "
    echo $daos_cmd
    echo
    eval $cmd &

    wait_for_servers_to_start ${DAOS_SERVERS}
}

#Run IOR
run_ior(){
    echo -e "\nCMD: Starting IOR..."
    module unload intel
    module list
    no_of_ps=$(($DAOS_CLIENTS * $PPC))
    echo

    IOR_WR_CMD="ior
             -a DFS -b ${BLOCK_SIZE} -C -e -w -W -g -G 27 -k -i 1
             -s ${SEGMENTS} -o /testFile
             -O stoneWallingWearOut=1
             -O stoneWallingStatusFile=${RUN_DIR}/sw.${SLURM_JOB_ID} -D 60
             -d 5 -t ${XFER_SIZE} --dfs.cont ${CONT_UUID}
             --dfs.group daos_server --dfs.pool ${POOL_UUID} --dfs.oclass ${OCLASS}
             --dfs.svcl ${POOL_SVC} -vvv"

    IOR_RD_CMD="ior
             -a DFS -b ${BLOCK_SIZE} -C -Q 1 -e -r -R -g -G 27 -k -i 1
             -s ${SEGMENTS} -o /testFile
             -O stoneWallingWearOut=1
             -O stoneWallingStatusFile=${RUN_DIR}/sw.${SLURM_JOB_ID} -D 60
             -d 5 -t ${XFER_SIZE} --dfs.cont ${CONT_UUID}
             --dfs.group daos_server --dfs.pool ${POOL_UUID} --dfs.oclass ${OCLASS}
             --dfs.svcl ${POOL_SVC} -vvv"

    prefix_mpich="mpirun
             -np $no_of_ps -map-by node
             -hostfile ${CLIENT_HOSTLIST_FILE}"

    prefix_openmpi="orterun $OMPI_PARAM
                 -x CPATH -x PATH -x LD_LIBRARY_PATH
                 -x CRT_PHY_ADDR_STR -x OFI_DOMAIN -x OFI_INTERFACE
                 -x FI_MR_CACHE_MAX_COUNT -x FI_UNIVERSE_SIZE
                 -x FI_VERBS_PREFER_XRC
                 --timeout $OMPI_TIMEOUT -np $no_of_ps --map-by node
                 --hostfile ${CLIENT_HOSTLIST_FILE}"

    mpich_cmd="${prefix_mpich} ${IOR_WR_CMD};
               ${prefix_mpich} ${IOR_RD_CMD}"

    openmpi_cmd="${prefix_openmpi} ${IOR_WR_CMD};
                 ${prefix_openmpi} ${IOR_RD_CMD}"

    if [ "$MPI" == "openmpi" ]; then
        cmd=$openmpi_cmd
    else
        cmd=$mpich_cmd
    fi

    echo $cmd
    echo
    eval $cmd
    RC=$?

    get_daos_status

    if [ ${RC} -ne 0 ]; then
        echo -e "\nSTATUS: IOR FAIL\n"
        module load intel
        module list
        teardown_test
    else
        echo -e "\nSTATUS: IOR SUCCESS\n"
    fi
    module load intel
    module list
    sleep 5
}

#Run cart self_test
run_self_test(){
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
        -x CPATH -x PATH -x LD_LIBRARY_PATH -x FI_MR_CACHE_MAX_COUNT
        -x CRT_PHY_ADDR_STR -x OFI_DOMAIN -x OFI_INTERFACE
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
    eval $cmd

    if [ $? -ne 0 ]; then
        echo -e "\nSTATUS: CART self_test FAIL\n"
        teardown_test
    else
        echo -e "\nSTATUS: CART self_test SUCCESS\n"
    fi
}

run_mdtest(){
    echo -e "\nCMD: Starting MDTEST...\n"
    module unload intel
    module list
    no_of_ps=$(($DAOS_CLIENTS * $PPC))
    echo

    mdtest_cmd="mdtest
                -a DFS --dfs.destroy --dfs.pool ${POOL_UUID}
                --dfs.cont $(uuidgen) --dfs.svcl ${POOL_SVC}
                --dfs.dir_oclass ${DIR_OCLASS} --dfs.oclass ${OCLASS}
                -L -p 10 -F -N 1 -P -d / -W 90
                -e ${BYTES_READ} -w ${BYTES_WRITE} -z ${TREE_DEPTH}
                -n ${N_FILE} -x ${RUN_DIR}/sw.${SLURM_JOB_ID} -vvv"

    mpich_cmd="mpirun
              -np $no_of_ps -map-by node
              -hostfile ${CLIENT_HOSTLIST_FILE}
              $mdtest_cmd"

    openmpi_cmd="orterun $OMPI_PARAM
                -x CPATH -x PATH -x LD_LIBRARY_PATH
                -x CRT_PHY_ADDR_STR -x OFI_DOMAIN -x OFI_INTERFACE
                -x FI_MR_CACHE_MAX_COUNT -x FI_UNIVERSE_SIZE
                -x FI_VERBS_PREFER_XRC
                --timeout $OMPI_TIMEOUT -np $no_of_ps --map-by node
                --hostfile ${CLIENT_HOSTLIST_FILE}
                $mdtest_cmd"

    if [ "$MPI" == "openmpi" ]; then
        cmd=$openmpi_cmd
    else
        cmd=$mpich_cmd
    fi

    echo $cmd
    echo
    eval $cmd
    RC=$?

    get_daos_status

    if [ ${RC} -ne 0 ]; then
        echo -e "\nSTATUS: MDTEST FAIL\n"
        module load intel
        module list
        teardown_test
    else
        echo -e "\nSTATUS: MDTEST SUCCESS\n"
    fi
    module load intel
    module list
    sleep 5
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

    pmsg "Retrieving local time of each node"
    run_cmd "clush --hostfile ${ALL_HOSTLIST_FILE} \
                   -f ${SLURM_JOB_NUM_NODES} \
                   ${DST_DIR}/print_node_local_time.sh"

    get_daos_status

    pmsg "Waiting to kill ${DOOMED_SERVER} server in ${WAIT_TIME} seconds..."
    sleep ${WAIT_TIME}
    pmsg "Killing ${DOOMED_SERVER} server"
    run_cmd "ssh ${DOOMED_SERVER} \"pgrep -a ${PROCESSES}\""
    run_cmd "ssh ${DOOMED_SERVER} \"pkill -e ${PROCESSES}\""
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
    #Prepare Enviornment
    prepare

    echo "###################"
    echo "RUN: $TESTCASE"
    echo "Start Time: $(date)"
    echo "###################"

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

run_testcase |& tee ${RUN_DIR}/output_${SLURM_JOB_ID}.txt

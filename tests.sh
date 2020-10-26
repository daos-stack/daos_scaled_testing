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
DAOS_SERVER_YAML="$PWD/Log/$SLURM_JOB_ID/daos_server.yml"
DAOS_AGENT_YAML="$PWD/Log/$SLURM_JOB_ID/daos_agent.yml"
DAOS_CONTROL_YAML="$PWD/Log/$SLURM_JOB_ID/daos_control.yml"
INITIAL_BRINGUP_WAIT_TIME=60s
WAIT_TIME=30s
MAX_RETRY_ATTEMPTS=6

HOSTNAME=$(hostname)
echo $HOSTNAME
echo
BUILD=`ls -al $DAOS_DIR/../../latest`
echo $BUILD
echo
pushd $DAOS_DIR
git log | head -n 1
popd
echo
source env_daos $DAOS_DIR

export PATH=~/utils/install/$MPI/bin:$PATH
export LD_LIBRARY_PATH=~/utils/install/$MPI/lib:$LD_LIBRARY_PATH

export PATH=$DAOS_DIR/install/ior_$MPI/bin:$PATH
export LD_LIBRARY_PATH=$DAOS_DIR/install/ior_$MPI/lib:$LD_LIBRARY_PATH

echo PATH=$PATH
echo
echo LD_LIBRARY_PATH=$LD_LIBRARY_PATH
echo

echo DAOS_SERVERS=$DAOS_SERVERS

cleanup(){
    mv *$SLURM_JOB_ID Log/$SLURM_JOB_ID/
    mkdir -p Log/$SLURM_JOB_ID/cleanup
    $SRUN_CMD copy_log_files.sh "cleanup"
    $SRUN_CMD cleanup.sh $DAOS_SERVERS
    echo "End Time: $(date)"
}

trap cleanup EXIT

#Wait for all the DAOS servers to start
function wait_for_servers_to_start(){
  TARGET_SERVERS=$((${1} - 1))

  echo "Waiting for [0-${TARGET_SERVERS}] daos_servers to start (${INITIAL_BRINGUP_WAIT_TIME} seconds)"
  sleep ${INITIAL_BRINGUP_WAIT_TIME}

  n=1
  until [ ${n} -ge ${MAX_RETRY_ATTEMPTS} ]
  do
    DMG_OUT=$(dmg -o ${DAOS_CONTROL_YAML} system query)
    echo "${DMG_OUT}"

    if echo ${DMG_OUT} | grep -q "\[0\-${TARGET_SERVERS}\]\sJoined"; then
      break
    fi
    echo "Attempt ${n} failed, retrying in ${WAIT_TIME} seconds..."
    n=$[${n} + 1]
    sleep ${WAIT_TIME}
  done

  if [ ${n} -ge ${MAX_RETRY_ATTEMPTS} ]; then
    echo "Failed to start all the DAOS servers"
    exit 1
  fi

  echo "Done, ${CURRENT_SERVERS_UP} DAOS servers are up and running"
}

#Create server/client hostfile.
prepare(){
    #Create the folder for server/client logs.
    mkdir -p Log/$SLURM_JOB_ID
    cp daos_server.yml daos_agent.yml daos_control.yml Log/$SLURM_JOB_ID/
    $SRUN_CMD create_log_dir.sh "cleanup"

    if [ $MPI == "openmpi" ]; then
        ./openmpi_gen_hostlist.sh $DAOS_SERVERS $DAOS_CLIENTS
    else
	./mpich_gen_hostlist.sh $DAOS_SERVERS $DAOS_CLIENTS
    fi

    ACCESS_POINT=`cat Log/$SLURM_JOB_ID/daos_server_hostlist | head -1 | grep -o -m 1 "^c[0-9\-]*"`

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
    cmd="clush --hostfile Log/$SLURM_JOB_ID/daos_all_hostlist
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
    cmd="daos_agent -i -o $DAOS_AGENT_YAML dump-attachinfo -o Log/$SLURM_JOB_ID/daos_server.attach_info_tmp"
    echo $cmd
    echo
    eval $cmd &
    sleep 20
}

#Create Pool
create_pool(){
    echo -e "\nCMD: Creating pool\n"
    cmd="dmg -o $DAOS_CONTROL_YAML pool create --scm-size $POOL_SIZE"
    echo $cmd
    echo
    DAOS_POOL=`$cmd`
    if [ $? -ne 0 ]; then
        echo "DMG pool create FAIL"
        exit 1
    else
        echo "DMG pool create SUCCESS"
    fi

    POOL_UUID="$(grep -o "UUID: [A-Za-z0-9\-]*" <<< $DAOS_POOL | awk '{print $2}')"
    POOL_SVC="$(grep -o "Service replicas: [A-Za-z0-9\-]*" <<< $DAOS_POOL | awk '{print $3}')"
    echo -e "\n====== POOL INFO ======"
    echo POOL_UUID: $POOL_UUID
    echo POOL_SVC : $POOL_SVC

    cmd="dmg pool set-prop --pool=$POOL_UUID --name=reclaim --value=disabled -o $DAOS_CONTROL_YAML"
    echo $cmd
    echo
    eval $cmd
    if [ $? -ne 0 ]; then
        echo "DMG pool set-prop FAIL"
        exit 1
    else
        echo "DMG pool set-prop SUCCESS"
    fi

    sleep 10
}

#Create Container
create_container(){
    echo -e "\nCMD: Creating container\n"

    CONT_UUID=$(uuidgen)
    HOST=$(head -n 1 Log/$SLURM_JOB_ID/daos_server_hostlist)
    echo CONT_UUID = $CONT_UUID
    echo HOST $HOST
    daos_cmd="daos cont create --pool=$POOL_UUID --svc=$POOL_SVC --cont $CONT_UUID --type=POSIX --properties=dedup:memcmp"
    cmd="clush -w $HOST 
    -f $SLURM_JOB_NUM_NODES \"
    export PATH=$PATH; export LD_LIBRARY_PATH=$LD_LIBRARY_PATH;
    export CPATH=$CPATH; export DAOS_DISABLE_REQ_FWD=1;
    export DAOS_AGENT_DRPC_DIR=$DAOS_AGENT_DRPC_DIR;
    $daos_cmd\""

    echo $daos_cmd
    eval $cmd
    if [ $? -ne 0 ]; then
        echo "Daos container create FAIL"
        exit 1
    else
        echo "Daos container create SUCCESS"
    fi

    daos_cmd="daos cont query --pool=$POOL_UUID --svc=$POOL_SVC --cont=$CONT_UUID"
    cmd="clush -w $HOST
    -f $SLURM_JOB_NUM_NODES \"
    export PATH=$PATH; export LD_LIBRARY_PATH=$LD_LIBRARY_PATH;
    export CPATH=$CPATH; export DAOS_DISABLE_REQ_FWD=1;
    export DAOS_AGENT_DRPC_DIR=$DAOS_AGENT_DRPC_DIR;
    $daos_cmd\""

    echo $daos_cmd
    eval $cmd
    if [ $? -ne 0 ]; then
        echo "Daos container query FAIL"
        exit 1
    else
        echo "Daos container query SUCCESS"
    fi
}

#Start daos servers
start_server(){
    echo -e "\nCMD: Starting server...\n"
    daos_cmd="daos_server start -i -o $DAOS_SERVER_YAML --recreate-superblocks"
    cmd="clush --hostfile Log/$SLURM_JOB_ID/daos_server_hostlist 
    -f $SLURM_JOB_NUM_NODES \"
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
    no_of_ps=$(($DAOS_CLIENTS * $PPC))
    echo

    ior_cmd="ior
             -a DFS -b $BLOCK_SIZE -w -W -r -R -g -G 27 -C -Q 1 -i 2 -s 1 -o /testFile 
             -t $XFER_SIZE --dfs.cont $CONT_UUID
             --daos.group daos_server --dfs.pool $POOL_UUID --dfs.oclass SX
             --dfs.svcl $POOL_SVC -vv"

    mpich_cmd="mpirun
             -np $no_of_ps -map-by node
             -hostfile Log/$SLURM_JOB_ID/daos_client_hostlist
	     $ior_cmd"

    openmpi_cmd="orterun $OMPI_PARAM 
		 -x CPATH -x PATH -x LD_LIBRARY_PATH
		 -x CRT_PHY_ADDR_STR -x OFI_DOMAIN -x OFI_INTERFACE
                 --timeout $OMPI_TIMEOUT -np $no_of_ps --map-by node
                 --hostfile Log/$SLURM_JOB_ID/daos_client_hostlist
		 $ior_cmd" 

    if [ "$MPI" == "openmpi" ]; then
        cmd=$openmpi_cmd
    else
	cmd=$mpich_cmd
    fi

    echo $cmd
    echo
    eval $cmd
    if [ $? -ne 0 ]; then
        echo -e "\nSTATUS: IOR FAIL\n"
        exit 1
    else
        echo -e "\nSTATUS: IOR SUCCESS\n"
    fi
    sleep 5
}

#Run cart self_test
run_self_test(){
    echo -e "\nCMD: Starting CaRT self_test...\n"

    let last_srv_index=$(( ${DAOS_SERVERS}-1 ))

    st_cmd="self_test
        --path Log/$SLURM_JOB_ID
        --group-name daos_server --endpoint 0-${last_srv_index}:0
        --message-sizes 'b1048576',' b1048576 0','0 b1048576',' b1048576 i2048',' i2048 b1048576',' i2048',' i2048 0','0 i2048','0' 
        --max-inflight-rpcs $INFLIGHT --repetitions 100 -t -n"

    mpich_cmd="mpirun --prepend-rank
        -np 1 -map-by node
        -hostfile Log/$SLURM_JOB_ID/daos_client_hostlist
        $st_cmd"

    openmpi_cmd="orterun $OMPI_PARAM 
        -x CPATH -x PATH -x LD_LIBRARY_PATH -x FI_MR_CACHE_MAX_COUNT
        -x CRT_PHY_ADDR_STR -x OFI_DOMAIN -x OFI_INTERFACE
        --timeout $OMPI_TIMEOUT -np 1 --map-by node
        --hostfile Log/$SLURM_JOB_ID/daos_client_hostlist
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
        exit 1
    else
        echo -e "\nSTATUS: CART self_test SUCCESS\n"
    fi
}

run_mdtest(){
    echo -e "\nCMD: Starting MDTEST...\n"
    for i in "${IOR_PROC_PER_CLIENT[@]}"; do
       no_of_ps=$(($DAOS_CLIENTS * $i))
       echo
        mdtest_cmd="mdtest
             -a DFS --dfs.destroy --dfs.pool $POOL_UUID
             --dfs.cont $(uuidgen) --dfs.svcl $POOL_SVC
             -n 500  -u -L --dfs.oclass S1 -N 1 -P -d /"

        mpich_cmd="mpirun
             -np $no_of_ps -map-by node
             -hostfile Log/$SLURM_JOB_ID/daos_client_hostlist
             $mdtest_cmd"

        openmpi_cmd="orterun $OMPI_PARAM
             -x CPATH -x PATH -x LD_LIBRARY_PATH
             -x CRT_PHY_ADDR_STR -x OFI_DOMAIN -x OFI_INTERFACE
             --timeout $OMPI_TIMEOUT -np $no_of_ps --map-by node
             --hostfile Log/$SLURM_JOB_ID/daos_client_hostlist
             $mdtest_cmd"

        if [ "$MPI" == "openmpi" ]; then
            cmd=$openmpi_cmd
        else
            cmd=$mpich_cmd
        fi

        echo $cmd
       echo
        eval $cmd
        if [ $? -ne 0 ]; then
            echo -e "\nSTATUS: process_per_client=$i - MDTEST FAIL\n"
            exit 1
        else
            echo -e "\nSTATUS: process_per_client=$i - MDTEST SUCCESS\n"
        fi
    done
}

#Prepare Enviornment
prepare

test=$1

echo "###################"
echo "RUN: $TESTCASE"
echo "Start Time: $(date)"
echo "###################"

case $test in
    IOR)
        start_server
        start_agent
        create_pool
        create_container
        run_ior
        ;;
    SELF_TEST)
        start_server
        dump_attach_info
        run_self_test
        ;;
    MDTEST)
        #Temporary disabled mdtest for automation updates
        #start_server
        #start_agent
        #create_pool
        #run_mdtest
        ;;  
    *)
        echo "Unknown test: Please use IOR, SELF_TEST or MDTEST"
esac


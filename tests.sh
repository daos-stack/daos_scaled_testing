#!/bin/bash
#----------------------------------------------------
#Run daos tests like IOR/MDtest and self_test(cart)
#----------------------------------------------------

#SBATCH -o stdout.o%j           # Name of stdout output file
#SBATCH -e stderr.e%j           # Name of stderr error file
#SBATCH -A STAR-Intel           # Project Name
#SBATCH --mail-type=all         # Send email at begin and end of job

#Parameters provided at sbatch invocation (order of parameters is important during manual testing)
TEST=$1
DAOS_SERVERS=$2
DAOS_CLIENTS=$3

if [ "$TEST" = SELF_TEST ] ; then
     ST_MAX_INFLIGHT=($4)
     ST_MIN_SRV=$(( $DAOS_SERVERS ))
     ST_MAX_SRV=$(( $DAOS_SERVERS ))
else
     NUM_TARGETS=$4
     RANKS_PER_CLIENT=$5
     REP_CLASS=$6
     SW_TIMEOUT=$7
     NUM_FILES=$8
     POOL_SIZE="85G"
fi

ACCESS_PORT=10001

RESULT_DIR="$PWD/Log/$SLURM_JOB_ID"

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

HOSTNAME=$(hostname)
echo $HOSTNAME
echo
BUILD=`ls -al $DAOS_DIR/../../latest`
echo $BUILD
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

ulimit -c unlimited

# Move the logs to the defined log location using cleanup.sh
cleanup(){
    mv *$SLURM_JOB_ID Log/$SLURM_JOB_ID/
    mv $RESULT_FILE Log/$SLURM_JOB_ID/
    mkdir -p Log/$SLURM_JOB_ID/cleanup
    $SRUN_CMD copy_log_files.sh "cleanup"
    $SRUN_CMD cleanup.sh $DAOS_SERVERS
}

trap cleanup EXIT

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

    if [ -z $NUM_TARGETS ] ; then
        sed -i "s/targets:.*/targets: $NUM_TARGETS/" $DAOS_SERVER_YAML
    fi

    #Create the daos_agent folder
    srun -n $SLURM_JOB_NUM_NODES mkdir  /tmp/daos_agent
    srun -n $SLURM_JOB_NUM_NODES mkdir  /tmp/daos_server

    # check arp settings
    clush  --hostfile $RESULT_DIR/daos_all_hostlist "cat /proc/sys/net/ipv4/neigh/default/gc_thresh1 ;
    cat  /proc/sys/net/ipv4/neigh/default/gc_thresh2 ;
    cat  /proc/sys/net/ipv4/neigh/default/gc_thresh3 " | sort >> Log/$SLURM_JOB_ID/gc_thresholds

}

#Start DAOS agent
start_agent(){
    echo -e "\nCMD: Starting agent...\n"
    fanout=$(($DAOS_CLIENTS+$DAOS_SERVERS+1))
    cmd="clush -f $fanout --hostfile $RESULT_DIR/all_hostlist \"
    export PATH=$PATH; export LD_LIBRARY_PATH=$LD_LIBRARY_PATH;
    export CPATH=$CPATH; export DAOS_DISABLE_REQ_FWD=1;
    daos_agent -o $DAOS_AGENT_YAML -s /tmp/daos_agent\" "
    echo $cmd
    echo
    eval $cmd &
    sleep 20
}

#Dump attach info
dump_attach_info(){
    echo -e "\nCMD: Dump attach info file...\n"
    #cmd="daos_agent -i -o $DAOS_AGENT_YAML dump-attachinfo -o Log/$SLURM_JOB_ID/daos_server.attach_info_tmp"
    cmd="daos_agent -i -o $DAOS_AGENT_YAML dump-attachinfo -o daos_server.attach_info_tmp"
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
    exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "DMG Create FAIL"
        exit 1
    else
        echo "DMG Create Pool Success"
    fi

    POOL_UUID="$(grep -o "UUID: [A-Za-z0-9\-]*" <<< $DAOS_POOL | awk '{print $2}')"
    POOL_SVC="$(grep -o "Service replicas: [A-Za-z0-9\-]*" <<< $DAOS_POOL | awk '{print $3}')"
    echo -e "\n====== POOL INFO ======"
    echo POOL_UUID: $POOL_UUID
    echo POOL_SVC : $POOL_SVC

    dmg pool set-prop --pool=$POOL_UUID --name=reclaim --value=disabled -o $DAOS_CONTROL_YAML
    sleep 10
}

#Destroy Pool
destroy_pool() {
    echo -e "\nCMD: Destroying pool\n"
    cmd="dmg  pool destroy --pool=$POOL_UUID"
    echo $cmd
}

#Query Pool
query_pool(){
    query_cmd="dmg  -o $DAOS_CONTROL_YAML pool query --pool $POOL_UUID"
    start=$(date +%s.%N)
    eval $query_cmd
    end=$(date +%s.%N)
    time_diff=$(echo "$end - $start" | bc)
    query_time=`printf "%.3f seconds" $time_diff`
    echo "Pool Query time was $query_time"
    echo
}

#Start daos servers
start_server(){
    echo -e "\nCMD: Starting server...\n"
    cmd="clush --hostfile Log/$SLURM_JOB_ID/daos_server_hostlist
    -f $SLURM_JOB_NUM_NODES \"
    export PATH=$PATH; export LD_LIBRARY_PATH=$LD_LIBRARY_PATH;
    export CPATH=$CPATH; export DAOS_DISABLE_REQ_FWD=1;
    daos_server start -i -o $DAOS_SERVER_YAML --recreate-superblocks \" 2>&1 "

    echo $cmd
    echo
    eval $cmd &

    # Need to implement a more reliable way to ensure all servers are up
    # maybe using dmg system query
    sleep 60;
}

#Run IOR
run_ior(){
    echo -e "\nCMD: Starting IOR..."

        TEST_TYPE="${TEST#IOR}"
        RESULT_FILE="ior-$TEST_TYPE-S$DAOS_SERVERS-T$NUM_TARGETS-C$DAOS_CLIENTS-P$RANKS_PER_CLIENT"
        no_of_procs=$(($DAOS_CLIENTS*$RANKS_PER_CLIENT))
        pool_size=85
        NUM_ITERS=1

        if [ "$TEST_TYPE" = "easy" ] ; then
            XFER_SIZE=1m
            BL_SIZE=150g
            segments=1
        else
            XFER_SIZE="47008"
            BL_SIZE="47008"
            segments=2000000
        fi

        query_pool

        echo num_servers: $DAOS_SERVERS "  " num_targets: $NUM_TARGETS "  "num_clients: $DAOS_CLIENTS "  " procs_per_client: $RANKS_PER_CLIENT | tee  -a $RESULT_FILE
        echo

        cont_create=`daos cont create --pool=$POOL_UUID --svc=$POOL_SVC --type=POSIX --properties=dedup:memcmp`
        exit_code=$?
        if [ $exit_code -ne 0 ]; then
            echo "CONT Create FAIL"
            exit 1
        else
            echo "CONT Create Success"
        fi

        echo cont: $cont_create
        CONT_UUID=`awk '{print $4}' <<< "$cont_create"`

        daos cont query --pool=$POOL_UUID --svc=$POOL_SVC --cont=$CONT_UUID

        ior_wr_cmd="ior
             -a DFS -b $BL_SIZE -C -e -w -W -g -G 27 -k -i $NUM_ITERS -s $segments -o /testFile
             -O stoneWallingWearOut=1 -O stoneWallingStatusFile=$PWD/sw.$SLURM_JOB_ID  -D $SW_TIMEOUT
             -d 5 -t $XFER_SIZE --dfs.cont $CONT_UUID
             --daos.group daos_server --dfs.pool $POOL_UUID --dfs.oclass $REP_CLASS
             --dfs.svcl $POOL_SVC  -vvv 2>&1 | tee -a $RESULT_FILE "

        ior_rd_cmd="ior
             -a DFS -b $BL_SIZE  -C -Q 1 -e -r -R -g -G 27 -k -i $NUM_ITERS -s $segments -o /testFile
             -O stoneWallingStatusFile=$PWD/sw.$SLURM_JOB_ID
             -d 5 -t $XFER_SIZE --dfs.cont $CONT_UUID
             --daos.group daos_server --dfs.pool $POOL_UUID --dfs.oclass $REP_CLASS
             --dfs.svcl $POOL_SVC  -vvv 2>&1 | tee -a $RESULT_FILE "

        mpich_prefix="mpirun
             -np $no_of_procs -map-by node
             -hostfile $RESULT_DIR/daos_client_hostlist "

        openmpi_prefix="orterun $OMPI_PARAM
             -x CPATH -x PATH -x LD_LIBRARY_PATH
             -x CRT_PHY_ADDR_STR -x OFI_DOMAIN -x OFI_INTERFACE
             --timeout 1800 -np $no_of_procs --map-by node
             --hostfile $RESULT_DIR/daos_client_hostlist "

        if [ "$MPI" == "openmpi" ]; then
            prefix=$openmpi_prefix
        else
            prefix=$mpich_prefix
        fi

        cmd="$prefix $ior_wr_cmd ; sleep 5 ; $prefix  $ior_rd_cmd"

        echo $cmd
        echo
        eval $cmd

        if [ $? -ne 0 ]; then
            echo -e "\nSTATUS: agg_size:$agg_size, block_size:$BL_SIZE transfer_size:$XFER_SIZE - IOReasy FAIL\n"
        else
            echo -e "\nSTATUS: agg_size:$agg_size, block_size:$BL_SIZE transfer_size:$XFER_SIZE - IOReasy SUCCESS\n"
        fi

        query_pool
}

#Run mdtest
run_mdtest(){
    echo -e "\nCMD: Starting MDTEST ...\n"
        echo
        TEST_TYPE="${TEST#MDT}"
        no_of_procs=$(($DAOS_CLIENTS * $RANKS_PER_CLIENT))
        RESULT_FILE="mdtest-$TEST_TYPE-S$DAOS_SERVERS-T$NUM_TARGETS-C$DAOS_CLIENTS-P$RANKS_PER_CLIENT"

        if [ "$TEST_TYPE" = "easy" ] ; then
            num_files=$(($NUM_FILES*7/2))
            params=" -u -L "
        else
            num_files=$NUM_FILES
            params=" -w 3901 -e 3901 -t -z 0/20 "
        fi

        query_pool

        echo num_servers: $DAOS_SERVERS "  " num_targets: $NUM_TARGETS "  "num_clients: $DAOS_CLIENTS "  " procs_per_client: $RANKS_PER_CLIENT | tee  -a $RESULT_FILE
        echo

        mdtest_cmd="mdtest
             -a DFS --dfs.destroy --dfs.pool $POOL_UUID
             --dfs.cont $(uuidgen) --dfs.svcl $POOL_SVC $params
             -p 10 -n $num_files -F --dfs.oclass S1 -N 1 -P -d / -W 300 -x sw.$SLURM_JOB_ID
             2>&1 | tee  -a $RESULT_FILE"

        mpich_cmd="mpirun
             -np $no_of_procs -map-by node
             -hostfile $RESULT_DIR/daos_client_hostlist
             $mdtest_cmd"

        openmpi_cmd="orterun $OMPI_PARAM
             -x CPATH -x PATH -x LD_LIBRARY_PATH
             -x CRT_PHY_ADDR_STR -x OFI_DOMAIN -x OFI_INTERFACE
             --timeout 1800 -np $no_of_procs --map-by node
             --hostfile $RESULT_DIR/daos_client_hostlist
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
            echo -e "\nSTATUS: MDTESTeasy FAIL\n"
        else
            echo -e "\nSTATUS: MDTESTeasy SUCCESS\n"
        fi

        query_pool
}

#Run cart self_test
run_self_test(){
    echo -e "\nCMD: Starting CaRT self_test...\n"

    while [  ${ST_MIN_SRV} -le ${ST_MAX_SRV} ]; do
	let last_srv_index=$(( ${ST_MIN_SRV}-1 ))

        for max_inflight in "${ST_MAX_INFLIGHT[@]}"; do
            st_cmd="self_test
		 --path Log/$SLURM_JOB_ID
                 --group-name daos_server --endpoint 0-${last_srv_index}:0
                 --message-sizes 'b1048576',' b1048576 0','0 b1048576',' b1048576 i2048',' i2048 b1048576',' i2048',' i2048 0','0 i2048','0' 
                 --max-inflight-rpcs ${max_inflight} --repetitions 100 -t -n"

            mpich_cmd="mpirun --prepend-rank
                 -np 1 -map-by node 
                 -hostfile Log/$SLURM_JOB_ID/daos_client_hostlist
                 $st_cmd"

            openmpi_cmd="orterun $OMPI_PARAM 
                 -x CPATH -x PATH -x LD_LIBRARY_PATH -x FI_MR_CACHE_MAX_COUNT
                 -x CRT_PHY_ADDR_STR -x OFI_DOMAIN -x OFI_INTERFACE
                 --timeout 600 -np 1 --map-by node 
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
	done

	let ST_MIN_SRV=$(( ${ST_MIN_SRV}*2 ))
    done
}

#Prepare Enviornment
prepare


echo "###################"
echo "RUN: $TEST"
echo "###################"

echo $TEST

case $TEST in
    IOR*)
        start_server
        start_agent
        create_pool
        run_ior
        sleep 20
        destroy_pool
        ;;
    MDT*)
        start_server
        start_agent
        create_pool
        run_mdtest
        sleep 20
        destroy_pool
        ;;  
    SELF_TEST)
        start_server
        dump_attach_info
        run_self_test
        ;;
    *)
        echo "Unknown test: Please use IOReasy, IORhard, MDTeasy, MDThard or SELF_TEST"
esac


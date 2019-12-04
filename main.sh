#!/bin/bash
#----------------------------------------------------
#Run daos tests like IOR/MDtest and self_test(cart)
#----------------------------------------------------

#SBATCH -J test_daos1           # Job name
#SBATCH -o stdout.o%j           # Name of stdout output file
#SBATCH -e stderr.e%j           # Name of stderr error file
#SBATCH -A STAR-Intel		# Project Name
#SBATCH -p development        	# Queue (partition) name
#SBATCH -N 4              	# Total # of nodes
#SBATCH -n 192                	# Total # of mpi tasks (48 x  Total # of nodes)
#SBATCH -t 1:00:00             # Run time (hh:mm:ss)
#SBATCH --mail-user=first.last@intel.com
#SBATCH --mail-type=all         # Send email at begin and end of job

#Parameter to be updated for each sbatch
DAOS_SERVERS=2
DAOS_CLIENTS=1
DAOS_DIR="/home1/<USER_HOME_FOLDER>/daos"

#IOR Parameter
IOR_PROC_PER_CLIENT=(8 4 1)
TRANSFER_SIZES=(256B 4K 128K 512K 1M)
BL_SIZE="64M"

#Cart Self test parameter
SELF_TEST_RPC=(1 16)

#Others
SRUN_CMD="srun -n $SLURM_JOB_NUM_NODES -N $SLURM_JOB_NUM_NODES"
URI_FILE="uri.txt"
DAOS_SERVER_YAML="$PWD/daos_server_psm2.yml"
PSM2_CLIENT_PARAM="--mca mtl ^psm2,ofi -x FI_PSM2_DISCONNECT=1 --mca btl tcp,self --mca oob tcp"

HOSTNAME=$(hostname)
echo $HOSTNAME
source env_daos $DAOS_DIR

#Collect logs from all servers/clients
collect_logs(){
    mkdir -p Log/$SLURM_JOB_ID/$1
    $SRUN_CMD copy_log_files.sh $1
    $SRUN_CMD cleanup.sh
}

#Kill all process in case of failure or end of each test runs
killall_proc(){
    collect_logs $1
    $SRUN_CMD killall_proc.sh
    sleep 10
}

#Cleanup the SCM content and kill the processes.
cleanup (){
    mv *$SLURM_JOB_ID Log/$SLURM_JOB_ID/
    killall_proc "cleanup"
}

trap cleanup EXIT

#Create server/client hostfile.
prepare(){
    #Create the folder for server/client logs.
    mkdir Log/$SLURM_JOB_ID
    $SRUN_CMD create_log_dir.sh "cleanup"

    #Prepare DAOS server list file
    srun -n $SLURM_JOB_NUM_NODES hostname > Log/$SLURM_JOB_ID/slurm_hostlist
    sed -i "/$HOSTNAME/d" Log/$SLURM_JOB_ID/slurm_hostlist
    cat Log/$SLURM_JOB_ID/slurm_hostlist | tail -$DAOS_SERVERS > Log/$SLURM_JOB_ID/slurm_server_hostlist
    sed 's/$/ slots=1/' Log/$SLURM_JOB_ID/slurm_server_hostlist > Log/$SLURM_JOB_ID/daos_server_hostlist
    cat Log/$SLURM_JOB_ID/slurm_hostlist | head -$DAOS_CLIENTS > Log/$SLURM_JOB_ID/daos_client_hostlist

    #Create the daos_agent folder
    srun -n $SLURM_JOB_NUM_NODES mkdir  /tmp/daos_agent

    #Create the daos attach info folder
    mkdir -p $DAOS_DIR/install/tmp/
}

#Prepare log folders for tests
prepare_test_log_dir(){
    $SRUN_CMD create_log_dir.sh $1
}

#Start DAOS agent
start_agent(){
    srun -n $SLURM_JOB_NUM_NODES $DAOS_DIR/install/bin/daos_agent -i -o $DAOS_SERVER_YAML -s /tmp/daos_agent &
    sleep 10
}

#Create Pool
create_pool(){
    daos_cmd="orterun $PSM2_CLIENT_PARAM --ompi-server file:$URI_FILE -np 1  --map-by node 
    --hostfile Log/$SLURM_JOB_ID/daos_client_hostlist  dmg_old create --size=42G"
    DAOS_POOL=`$daos_cmd`
    exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "----DMG Create FAIL"
        exit 1
    else
        echo "--------DMG Create Pool Success"
    fi

    POOL_UUID="$(echo "$DAOS_POOL" |  awk '{print $1}')"
    POOL_SVC="$(echo "$DAOS_POOL" |  awk '{print $2}')"
    echo "------------POOL INFO-----------------------------"
    echo $POOL_UUID
    echo $POOL_SVC
    echo "--------------------------------------------------"
}

#Start daos servers
start_server(){
    rm -r server_output.log
    cmd="orterun  --np $DAOS_SERVERS --hostfile Log/$SLURM_JOB_ID/daos_server_hostlist -x CPATH -x PATH -x LD_LIBRARY_PATH 
    --report-uri $URI_FILE --enable-recovery daos_server start -i -a $DAOS_DIR/install/tmp/ -o $DAOS_SERVER_YAML  
    --recreate-superblocks 2>&1 | tee server_output.log"
    echo $cmd
    eval $cmd &
    TIMEOUT=0
    while :
        do
        VAL=`cat server_output.log | grep "started on rank" | wc -l`
        if (($TIMEOUT > 30)); then
            echo "FAIL: Failed to start DAOS servers"
            exit 1
        elif (($DAOS_SERVERS == $VAL));then
            break
        else
            echo "Waiting to start all servers....."
            sleep 10
            let "TIMEOUT++"
        fi
    done
}

#Run IOR
run_IOR(){
    for size in "${TRANSFER_SIZES[@]}"; do
        for i in "${IOR_PROC_PER_CLIENT[@]}"; do
            no_of_ps=$(($DAOS_CLIENTS * $i))
            IOR_CMD="orterun --timeout 600 $PSM2_CLIENT_PARAM --ompi-server file:$URI_FILE 
            -np $no_of_ps --map-by node  --hostfile Log/$SLURM_JOB_ID/daos_client_hostlist ior -a DAOS -b $BL_SIZE  -w -r -i 3 -o daos:testFile 
            -t $size --daos.cont $(uuidgen) --daos.destroy --daos.group daos_server --daos.pool $POOL_UUID  --daos.svcl $POOL_SVC -vv"
            echo $IOR_CMD
            $IOR_CMD
            sleep 5
        done
    done
}

#Run daos_test
run_daos_test(){
    #Run daos_test from single client for now.
    daos_cmd="orterun --timeout 1800 $PSM2_CLIENT_PARAM  --ompi-server file:$URI_FILE -np 1  --map-by node
    --hostfile Log/$SLURM_JOB_ID/daos_client_hostlist  daos_test -p"
    echo $daos_cmd
    eval $daos_cmd
    if [ $? -ne 0 ]; then
        echo "----daos_test FAIL"
	exit 1
    else
        echo "--------daos_test Success"
    fi
}

#Run cart self_test
run_cart_test(){
    END_POINTS="-`expr $DAOS_SERVERS - 1`"
    for rpc in "${SELF_TEST_RPC[@]}"; do
        for point in 0 1; do
                daos_cmd="orterun --timeout 3600 $PSM2_CLIENT_PARAM -np 1 -ompi-server file:$URI_FILE self_test
		--group-name daos_server --endpoint 0-$point:0 --master-endpoint 0$END_POINTS:0
	        --message-sizes 'b1048576',' b1048576 0','0 b1048576',' b1048576 i2048',' i2048 b1048576',' i2048',' i2048 0','0 i2048','0' 
        	--max-inflight-rpcs $rpc --repetitions 100"
	        echo $daos_cmd
        	eval $daos_cmd
	        if [ $? -ne 0 ]; then
        	    echo "----CART self_test FAIL"
        	    exit 1
	        else
        	    echo "--------CART self_test Success"
	        fi
        done
    done
}

run_mdtest(){
    for i in "${IOR_PROC_PER_CLIENT[@]}"; do
        cmd="orterun --timeout 600 $PSM2_CLIENT_PARAM --ompi-server file:$URI_FILE -np $i --map-by node
        --hostfile Log/$SLURM_JOB_ID/daos_client_hostlist mdtest -a DFS  --dfs.destroy --dfs.pool $POOL_UUID 
        --dfs.cont $(uuidgen) --dfs.svcl $POOL_SVC -n 1000 -z  0/20  -d /"
        echo $cmd
        eval $cmd
        if [ $? -ne 0 ]; then
            echo "----MDTEST FAIL"
            exit 1
        else
            echo "--------MDTEST Success"
        fi
    done
}

#Prepare Enviornment
prepare

for test in "$@"; do
    echo "Run $test Test"
    prepare_test_log_dir $test
    case $test in
        IOR)
            start_server
            create_pool
            start_agent
            run_IOR
            killall_proc $test
            ;;
        DAOS_TEST)
            start_server
            start_agent
            run_daos_test
            killall_proc $test
            ;;
        SELF_TEST)
            start_server
            run_cart_test
            killall_proc $test
            ;;
        MDTEST)
            start_server
            create_pool
            start_agent
            run_mdtest
            killall_proc $test
            ;;  
        *)
            echo "Unknow test: Please use IOR DAOS_TEST SELF_TEST or MDTEST"
    esac
done


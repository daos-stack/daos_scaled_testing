#!/bin/bash
#----------------------------------------------------
#Run daos tests like IOR/MDtest and self_test(cart)
#----------------------------------------------------

#SBATCH -J test_daos1           # Job name
#SBATCH -o stdout.o%j           # Name of stdout output file
#SBATCH -e stderr.e%j           # Name of stderr error file
#SBATCH -A STAR-Intel           # Project Name
#SBATCH -p skx-dev              # Queue (partition) name
#SBATCH -N 4                    # Total # of nodes
#SBATCH -n 192                  # Total # of mpi tasks (48 x  Total # of nodes)
#SBATCH -t 1:00:00             # Run time (hh:mm:ss)
#SBATCH --mail-user=first.last@intel.com
#SBATCH --mail-type=all         # Send email at begin and end of job

#Parameter to be updated for each sbatch
DAOS_SERVERS=2
DAOS_CLIENTS=1
ACCESS_PORT=10001
DAOS_DIR="/home1/<USER_HOME_FOLDER>/daos"
POOL_SIZE="42G"

#IOR Parameter
IOR_PROC_PER_CLIENT=(8 4 1)
TRANSFER_SIZES=(256B 4K 128K 512K 1M)
BL_SIZE="64M"

#Cart Self test parameter
SELF_TEST_RPC=(1 16)

#Others
SRUN_CMD="srun -n $SLURM_JOB_NUM_NODES -N $SLURM_JOB_NUM_NODES"
DAOS_SERVER_YAML="$PWD/daos_server_verbs.yml"
#PSM2_CLIENT_PARAM="--mca mtl ^psm2,ofi -x FI_PSM2_DISCONNECT=1 --mca btl tcp,self --mca oob tcp"
VERBS_CLIENT_PARAM=" --mca btl_openib_warn_default_gid_prefix 0 --mca pml ob1 --mca btl tcp,self --mca oob tcp"

HOSTNAME=$(hostname)
echo $HOSTNAME
source env_daos $DAOS_DIR

export PATH=~/utils/install/bin:$PATH
export LD_LIBRARY_PATH=~/utils/install/lib:$LD_LIBRARY_PATH

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
    mkdir -p Log/$SLURM_JOB_ID
    $SRUN_CMD create_log_dir.sh "cleanup"

    ./gen_hostlist.sh $DAOS_SERVERS $DAOS_CLIENTS

    ACCESS_POINT=`cat Log/$SLURM_JOB_ID/slurm_server_hostlist | head -1 | grep -o -m 1 "^c[0-9\-]*"`

    sed -i "/^access_points/ c\access_points: ['$ACCESS_POINT:$ACCESS_PORT']" $DAOS_SERVER_YAML

    #Create the daos_agent folder
    srun -n $SLURM_JOB_NUM_NODES mkdir  /tmp/daos_agent
}

#Prepare log folders for tests
prepare_test_log_dir(){
    $SRUN_CMD create_log_dir.sh $1
}

#Start DAOS agent
start_agent(){
    echo -e "\nCMD: Starting agent...\n"
    cmd="srun -n $SLURM_JOB_NUM_NODES $DAOS_DIR/install/bin/daos_agent -i -o $DAOS_SERVER_YAML -s /tmp/daos_agent"
    echo $cmd
    echo
    eval $cmd &
    sleep 10
}

#Create Pool
create_pool(){
    echo -e "\nCMD: Creating pool\n"
    cmd="dmg -l $ACCESS_POINT:$ACCESS_PORT -i pool create --scm-size $POOL_SIZE"
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
}

#Start daos servers
start_server(){
    echo -e "\nCMD: Starting server...\n"
    rm -r server_output.log
    cmd="orterun  --np $DAOS_SERVERS --hostfile Log/$SLURM_JOB_ID/daos_server_hostlist -x CPATH -x PATH -x LD_LIBRARY_PATH 
    --enable-recovery daos_server start -i -o $DAOS_SERVER_YAML  
    --recreate-superblocks 2>&1 | tee server_output.log"
    echo $cmd
    echo
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
    echo -e "\nCMD: Starting IOR..."
    for size in "${TRANSFER_SIZES[@]}"; do
        for i in "${IOR_PROC_PER_CLIENT[@]}"; do
            no_of_ps=$(($DAOS_CLIENTS * $i))
	    echo
            cmd="orterun --timeout 600 $PSM2_CLIENT_PARAM $VERBS_CLIENT_PARAM 
            -np $no_of_ps --map-by node  --hostfile Log/$SLURM_JOB_ID/daos_client_hostlist ior -a DAOS -b $BL_SIZE  -w -r -i 3 -o daos:testFile 
            -t $size --daos.cont $(uuidgen) --daos.destroy --daos.group daos_server --daos.pool $POOL_UUID  --daos.svcl $POOL_SVC -vv"
            echo $cmd
	    echo
            eval $cmd
            if [ $? -ne 0 ]; then
                echo -e "\nSTATUS: transfer_size=$size, process_per_client=$i - IOR FAIL\n"
                exit 1
            else
                echo -e "\nSTATUS: transfer_size=$size, process_per_client=$i - IOR SUCCESS\n"
            fi
	    sleep 5
        done
    done
}

#Run daos_test
run_daos_test(){
    echo -e "\nCMD: Starting daos_test...\n"
    #Run daos_test from single client for now.
    cmd="orterun --timeout 1800 $PSM2_CLIENT_PARAM -np 1 --map-by node
    --hostfile Log/$SLURM_JOB_ID/daos_client_hostlist daos_test -p"
    echo $cmd
    echo
    eval $cmd
    if [ $? -ne 0 ]; then
        echo -e "\nSTATUS: daos_test FAIL\n"
	exit 1
    else
        echo -e "\nSTATUS: daos_test SUCCESS\n"
    fi
}

#Run cart self_test
run_cart_test(){
    echo -e "\nCMD: Starting CaRT self_test...\n"
    END_POINTS="-`expr $DAOS_SERVERS - 1`"
    for rpc in "${SELF_TEST_RPC[@]}"; do
        for point in 0 1; do
                cmd="orterun --timeout 3600 $PSM2_CLIENT_PARAM -np 1 self_test
		--group-name daos_server --endpoint 0-$point:0 --master-endpoint 0$END_POINTS:0
	        --message-sizes 'b1048576',' b1048576 0','0 b1048576',' b1048576 i2048',' i2048 b1048576',' i2048',' i2048 0','0 i2048','0' 
        	--max-inflight-rpcs $rpc --repetitions 100"
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
    done
}

run_mdtest(){
    echo -e "\nCMD: Starting MDTEST...\n"
    for i in "${IOR_PROC_PER_CLIENT[@]}"; do
	no_of_ps=$(($DAOS_CLIENTS * $i))
	echo
        cmd="orterun --timeout 600 $PSM2_CLIENT_PARAM $VERBS_CLIENT_PARAM -np $no_of_ps --map-by node
        --hostfile Log/$SLURM_JOB_ID/daos_client_hostlist mdtest -a DFS  --dfs.destroy --dfs.pool $POOL_UUID 
        --dfs.cont $(uuidgen) --dfs.svcl $POOL_SVC -n 500  -u -L --dfs.oclass S1 -N 1 -P -d /"
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

for test in "$@"; do
    echo "###################"
    echo "RUN: $test Test"
    echo "###################"
    prepare_test_log_dir $test
    case $test in
        IOR)
            start_server
            start_agent
	    create_pool
            run_IOR
            killall_proc $test
            ;;
        DAOS_TEST)
            #start_server
            #start_agent
            #run_daos_test
            #killall_proc $test
	    echo "DAOS_TEST is temporarily disabled - TBD"
            ;;
        SELF_TEST)
            #start_server
            #run_cart_test
            #killall_proc $test
	    echo "SELF_TEST is temporarily disabled - DAOS-3838"
            ;;
        MDTEST)
            start_server
            start_agent
            create_pool
            run_mdtest
            killall_proc $test
            ;;  
        *)
            echo "Unknow test: Please use IOR DAOS_TEST SELF_TEST or MDTEST"
    esac
done


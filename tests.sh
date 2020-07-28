#!/bin/bash
#----------------------------------------------------
#Run daos tests like IOR/MDtest and self_test(cart)
#----------------------------------------------------

#SBATCH -o stdout.o%j           # Name of stdout output file
#SBATCH -e stderr.e%j           # Name of stderr error file
#SBATCH -A STAR-Intel           # Project Name
#SBATCH --mail-type=all         # Send email at begin and end of job

#Parameter to be updated for each sbatch
DAOS_SERVERS=$2
DAOS_CLIENTS=$3
ACCESS_PORT=10001
POOL_SIZE="60G"
MPI="openmpi" #supports openmpi or mpich
OMPI_PARAM="--mca oob ^ud --mca btl self,tcp --mca pml ob1"

if [ "$MPI" != "openmpi" ] && [ "$MPI" != "mpich" ]; then
    echo "Unknown MPI. Please specify either openmpi or mpich"
    exit 1
fi

#IOR Parameter
IOR_PROC_PER_CLIENT=(4)
TRANSFER_SIZES=(1M)
BL_SIZE="1G"

#Cart Self test parameter
ST_MAX_INFLIGHT=($4)
ST_MIN_SRV=$(( $DAOS_SERVERS ))
ST_MAX_SRV=$(( $DAOS_SERVERS ))

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

cleanup(){
    mv *$SLURM_JOB_ID Log/$SLURM_JOB_ID/
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

    #Create the daos_agent folder
    srun -n $SLURM_JOB_NUM_NODES mkdir  /tmp/daos_agent
    srun -n $SLURM_JOB_NUM_NODES mkdir  /tmp/daos_server
}

#Prepare log folders for tests
prepare_test_log_dir(){
    $SRUN_CMD create_log_dir.sh $1
}

#Start DAOS agent
start_agent(){
    echo -e "\nCMD: Starting agent...\n"
    cmd="clush --hostfile Log/$SLURM_JOB_ID/daos_all_hostlist \"
    export PATH=$PATH; export LD_LIBRARY_PATH=$LD_LIBRARY_PATH; export CPATH=$CPATH;
    export DAOS_DISABLE_REQ_FWD=1;
    daos_agent -o $DAOS_AGENT_YAML -s /tmp/daos_agent\" "
    echo $cmd
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
    cmd="clush --hostfile Log/$SLURM_JOB_ID/daos_server_hostlist \"
    export PATH=$PATH; export LD_LIBRARY_PATH=$LD_LIBRARY_PATH; export CPATH=$CPATH;
    export DAOS_DISABLE_REQ_FWD=1;
    daos_server start -i -o $DAOS_SERVER_YAML  
    --recreate-superblocks
    \" 2>&1 "
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
    for size in "${TRANSFER_SIZES[@]}"; do
        for i in "${IOR_PROC_PER_CLIENT[@]}"; do
            no_of_ps=$(($DAOS_CLIENTS * $i))
	    echo

	    ior_cmd="ior
                 -a DAOS -b $BL_SIZE  -w -r -i 2 -o daos:testFile 
                 -t $size --daos.cont $(uuidgen) --daos.destroy
                 --daos.group daos_server --daos.pool $POOL_UUID
                 --daos.svcl $POOL_SVC -vv"

            mpich_cmd="mpirun
		 -np $no_of_ps -map-by node 
                 -hostfile Log/$SLURM_JOB_ID/daos_client_hostlist
		 $ior_cmd"

	    openmpi_cmd="orterun $OMPI_PARAM 
		 -x CPATH -x PATH -x LD_LIBRARY_PATH
		 -x CRT_PHY_ADDR_STR -x OFI_DOMAIN -x OFI_INTERFACE
                 --timeout 600 -np $no_of_ps --map-by node 
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
                echo -e "\nSTATUS: transfer_size=$size, process_per_client=$i - IOR FAIL\n"
                exit 1
            else
                echo -e "\nSTATUS: transfer_size=$size, process_per_client=$i - IOR SUCCESS\n"
            fi
	    sleep 5
        done
    done
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
             --timeout 600 -np $no_of_ps --map-by node 
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
echo "###################"

case $test in
    IOR)
        start_server
        start_agent
        create_pool
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
        run_mdtest
        ;;  
    *)
        echo "Unknown test: Please use IOR, SELF_TEST or MDTEST"
esac


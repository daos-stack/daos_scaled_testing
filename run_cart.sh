#!/bin/bash
#---------------
#Run CaRT tests 
#---------------

#SBATCH -J test_daos1           # Job name
#SBATCH -o stdout.o%j           # Name of stdout output file
#SBATCH -e stderr.e%j           # Name of stderr error file
#SBATCH -A STAR-Intel           # Project Name
#SBATCH -p skx-dev              # Queue (partition) name
#SBATCH -N 4                    # Total # of nodes
#SBATCH -n 40                   # Total # of mpi tasks (48 x  Total # of nodes)
#SBATCH -t 1:00:00              # Run time (hh:mm:ss)
#SBATCH --mail-user=first.last@intel.com
#SBATCH --mail-type=all         # Send email at begin and end of job

#Parameter to be updated for each sbatch
DAOS_SERVERS=2
DAOS_CLIENTS=1
MAX_INFLIGHT=16
CARTDIR="/home1/<PATH_TO_CART>/cart"

interface=ib0
sep=0
timeout=7200

rm -rf testLogs

export PATH=${CARTDIR}/install/Linux/bin/:$PATH
export LD_LIBRARY_PATH=${CARTDIR}/install/Linux/lib/:$LD_LIBRARY_PATH

#Others
SRUN_CMD="srun -n $SLURM_JOB_NUM_NODES -N $SLURM_JOB_NUM_NODES"

HOSTNAME=$(hostname)
echo $HOSTNAME

function print_title {
        echo "*************" 
        echo "* $1"  
        echo "*************"  
        echo "" 
}

function wait {
        sleep $1

        echo "" 
        echo "" 
}

function run_bg {
        echo "CMD:"  
        echo orterun --map-by node --timeout $timeout --mca mtl ^psm2,ofi -x FI_PSM2_DISCONNECT=1 --np $1 --hostfile $2 --output-filename testLogs/$4/sep_$test_$sep -x D_LOG_FILE=testLogs/$4/sep_$test_$sep/srv_output.log -x D_LOG_MASK=ERR -x CRT_PHY_ADDR_STR=ofi+psm2 -x OFI_INTERFACE=$interface -x CRT_CTX_SHARE_ADDR=$sep -x CRT_CTX_NUM=16 -x PATH -x LD_LIBRARY_PATH $3

        echo "" 

        orterun --map-by node --timeout $timeout --mca mtl ^psm2,ofi -x FI_PSM2_DISCONNECT=1 --np $1 --hostfile $2 --output-filename testLogs/$4/sep_$test_$sep -x D_LOG_FILE=testLogs/$4/sep_$test_$sep/srv_output.log -x D_LOG_MASK=ERR -x CRT_PHY_ADDR_STR=ofi+psm2 -x OFI_INTERFACE=$interface -x CRT_CTX_SHARE_ADDR=$sep -x CRT_CTX_NUM=16 -x PATH -x LD_LIBRARY_PATH $3 &

        wait 5
}

function run_fg {
        echo "CMD:"
        echo orterun --map-by node --timeout $timeout --mca mtl ^psm2,ofi -x FI_PSM2_DISCONNECT=1 --np $1 --hostfile $2 --output-filename testLogs/$4/sep_$test_$sep -x D_LOG_FILE=testLogs/$4/sep_$test_$sep/srv_output.log -x D_LOG_MASK=ERR -x CRT_PHY_ADDR_STR=ofi+psm2 -x OFI_INTERFACE=$interface -x CRT_CTX_SHARE_ADDR=$sep -x CRT_CTX_NUM=16 -x PATH -x LD_LIBRARY_PATH $3

        echo ""

        orterun --map-by node --timeout $timeout --mca mtl ^psm2,ofi -x FI_PSM2_DISCONNECT=1 --np $1 --hostfile $2 --output-filename testLogs/$4/sep_$test_$sep -x D_LOG_FILE=testLogs/$4/sep_$test_$sep/srv_output.log -x D_LOG_MASK=ERR -x CRT_PHY_ADDR_STR=ofi+psm2 -x OFI_INTERFACE=$interface -x CRT_CTX_SHARE_ADDR=$sep -x CRT_CTX_NUM=16 -x PATH -x LD_LIBRARY_PATH $3

        ret=$?
        wait 5
        if [ $ret != 0 ]; then
                echo TEST FAILED!!! ret = $ret
        else
                echo TEST PASSED
        fi
        echo ""
}

function run_st {
        echo "CMD:"  
        echo orterun --map-by node --timeout $timeout --mca mtl ^psm2,ofi -x FI_PSM2_DISCONNECT=1 --np $1 --hostfile $2 --output-filename testLogs/$4/sep_$test_$sep -x D_LOG_FILE=testLogs/$4/sep_$test_$sep/srv_output.log -x D_LOG_MASK=ERR -x CRT_PHY_ADDR_STR=ofi+psm2 -x OFI_INTERFACE=$interface -x CRT_CTX_SHARE_ADDR=$sep -x CRT_CTX_NUM=16 -x PATH -x LD_LIBRARY_PATH $3 --message-sizes "b1048576,b1048576 0,0 b1048576,i2048,i2048 0,0 i2048,0"

        echo "" 

        orterun --map-by node --timeout $timeout --mca mtl ^psm2,ofi -x FI_PSM2_DISCONNECT=1 --np $1 --hostfile $2 --output-filename testLogs/$4/sep_$test_$sep -x D_LOG_FILE=testLogs/$4/sep_$test_$sep/srv_output.log -x D_LOG_MASK=ERR -x CRT_PHY_ADDR_STR=ofi+psm2 -x OFI_INTERFACE=$interface -x CRT_CTX_SHARE_ADDR=$sep -x CRT_CTX_NUM=16 -x PATH -x LD_LIBRARY_PATH $3 --message-sizes "b1048576,b1048576 0,0 b1048576,i2048,i2048 0,0 i2048,0"

        ret=$?
        wait 5
        if [ $ret != 0 ]; then
                echo TEST FAILED!!! ret = $ret
        else
                echo TEST PASSED
        fi
        echo ""
}

#Create server/client hostfile.
prepare(){
    #Create the folder for server/client logs.
    mkdir -p Log/$SLURM_JOB_ID

    #Prepare DAOS server list file
    srun -n $SLURM_JOB_NUM_NODES hostname > Log/$SLURM_JOB_ID/slurm_hostlist
    sed -i "/$HOSTNAME/d" Log/$SLURM_JOB_ID/slurm_hostlist
    cat Log/$SLURM_JOB_ID/slurm_hostlist | tail -$DAOS_SERVERS > Log/$SLURM_JOB_ID/slurm_server_hostlist
    sed 's/$/ slots=1/' Log/$SLURM_JOB_ID/slurm_server_hostlist > Log/$SLURM_JOB_ID/daos_server_hostlist
    cat Log/$SLURM_JOB_ID/slurm_hostlist | head -$DAOS_CLIENTS > Log/$SLURM_JOB_ID/daos_client_hostlist
}

run_selftest(){
    last_srv_index=$(( DAOS_SERVERS-1 ))
    run_bg $DAOS_SERVERS Log/$SLURM_JOB_ID/daos_server_hostlist "${CARTDIR}/install/Linux/bin/crt_launch -e ${CARTDIR}/install/Linux/TESTING/tests/test_group_np_srv --name selftest_srv_grp_$DAOS_SERVERS --cfg_path=${CARTDIR}/install/Linux/TESTING" $test
    wait 5
    run_st $DAOS_CLIENTS Log/$SLURM_JOB_ID/daos_client_hostlist "${CARTDIR}/install/Linux/bin/self_test --group-name selftest_srv_grp_$DAOS_SERVERS --endpoint 0-$last_srv_index:0 --master-endpoint 0:0 --max-inflight-rpcs $MAX_INFLIGHT --repetitions 100 -t -n -p ${CARTDIR}/install/Linux/TESTING" $test
    run_fg $DAOS_CLIENTS Log/$SLURM_JOB_ID/daos_client_hostlist "${CARTDIR}/install/Linux/TESTING/tests/test_group_np_cli --name client-group --attach_to selftest_srv_grp_$DAOS_SERVERS --shut_only --cfg_path=${CARTDIR}/install/Linux/TESTING" $test
}

for test in "$@"; do
    print_title $test
    case $test in
        sanity)
            prepare
            run_fg $DAOS_SERVERS Log/$SLURM_JOB_ID/daos_server_hostlist "hostname" $test
            ;;
        barrier)
            prepare
            run_fg $DAOS_SERVERS Log/$SLURM_JOB_ID/daos_server_hostlist "${CARTDIR}/install/Linux/bin/crt_launch -e ${CARTDIR}/install/Linux/TESTING/tests/test_crt_barrier" $test
            ;;
        self_test)
            let DAOS_SERVER=2
            until [  $DAOS_SERVERS -gt 65 ]; do
                prepare
                run_selftest
                let DAOS_SERVERS=$(( DAOS_SERVERS*2 ))
            done

            let DAOS_SERVERS=126
            prepare
            run_selftest
            ;;
    esac
done

mv stderr* stdout* testLogs Log/$SLURM_JOB_ID


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
N_SERVERS=2
N_CLIENTS=1
MAX_SERVERS=64
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

# run_server np cmd
function run_bg {
        echo "CMD:"  
        echo orterun --map-by node --timeout $timeout --mca mtl ^psm2,ofi -x FI_PSM2_DISCONNECT=1 --np $1 --hostfile $2 --output-filename testLogs/$4/sep_$test_$sep -x D_LOG_FILE=testLogs/$4/sep_$test_$sep/srv_output.log -x D_LOG_MASK=ERR -x CRT_PHY_ADDR_STR=ofi+psm2 -x OFI_INTERFACE=$interface -x CRT_CTX_SHARE_ADDR=$sep -x CRT_CTX_NUM=16 -x PATH -x LD_LIBRARY_PATH $3

        echo "" 

        orterun --map-by node --timeout $timeout --mca mtl ^psm2,ofi -x FI_PSM2_DISCONNECT=1 --np $1 --hostfile $2 --output-filename testLogs/$4/sep_$test_$sep -x D_LOG_FILE=testLogs/$4/sep_$test_$sep/srv_output.log -x D_LOG_MASK=ERR -x CRT_PHY_ADDR_STR=ofi+psm2 -x OFI_INTERFACE=$interface -x CRT_CTX_SHARE_ADDR=$sep -x CRT_CTX_NUM=16 -x PATH -x LD_LIBRARY_PATH $3 &

        wait 5
}

# run_server np cmd
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

# run_client np cmd
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

    ./gen_hostlist.sh $N_SERVERS $N_CLIENTS
}

run_selftest(){
    last_srv_index=$(( $N_SERVERS-1 ))
    run_bg $N_SERVERS Log/$SLURM_JOB_ID/daos_server_hostlist "${CARTDIR}/install/Linux/bin/crt_launch -e ${CARTDIR}/install/Linux/TESTING/tests/test_group_np_srv --name selftest_srv_grp_$N_SERVERS --cfg_path=${CARTDIR}/install/Linux/TESTING" $test
    wait 5
    run_st $N_CLIENTS Log/$SLURM_JOB_ID/daos_client_hostlist "${CARTDIR}/install/Linux/bin/self_test --group-name selftest_srv_grp_$N_SERVERS --endpoint 0-$last_srv_index:0 --master-endpoint 0:0 --max-inflight-rpcs $MAX_INFLIGHT --repetitions 100 -t -n -p ${CARTDIR}/install/Linux/TESTING" $test
    run_fg $N_CLIENTS Log/$SLURM_JOB_ID/daos_client_hostlist "${CARTDIR}/install/Linux/TESTING/tests/test_group_np_cli --name client-group --attach_to selftest_srv_grp_$N_SERVERS --shut_only --cfg_path=${CARTDIR}/install/Linux/TESTING" $test
}

for test in "$@"; do
    print_title $test
    case $test in
        sanity)
            prepare
            run_fg $N_SERVERS Log/$SLURM_JOB_ID/daos_server_hostlist "hostname" $test
            ;;
        barrier)
            prepare
            run_fg $N_SERVERS Log/$SLURM_JOB_ID/daos_server_hostlist "${CARTDIR}/install/Linux/bin/crt_launch -e ${CARTDIR}/install/Linux/TESTING/tests/test_crt_barrier" $test
            ;;
        self_test)
            let $N_SERVER=2
            until [  $N_SERVERS -ge $MAX_SERVERS ]; do
                prepare
                run_selftest
                let $N_SERVERS=$(( $N_SERVERS*2 ))
            done
            ;;
    esac
done

mv *$SLURM_JOB_ID testLogs Log/$SLURM_JOB_ID



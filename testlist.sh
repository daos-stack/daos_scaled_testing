#!/bin/sh

# This is the wrapper script to launch scale tests.

declare -a test_array
declare -A IOR_suite
declare -A MDT_suite

# Run all three test suites when no argument is given, else the specific test(s) given as arguments
if [ $# -eq 0 ] ; then
    test_array=(IOR MDT SELF_TEST)
else 
    test_array=("$@")  
fi
echo Tests to run are ${test_array[*]}

# IOR test suite
# Format:[<test name>]="min_servers max_servers num_targets num_ranks replication_type stonewall_timeout run/no_run"
IOR_suite=( [16Clnt_IOReasy_SX]="1 256 16 32 SX 300 YES" [16Clnt_IORhard_SX]="1 256 16 32 SX 300 YES"
            [16Clnt_IOReasy_2GX]="2 256 16 32 RP_2GX 300 NO" [16Clnt_IORhard_2GX]="2 256 16 32 RP_2GX 300 NO"
            [16Clnt_IOReasy_3GX]="4 256 16 32 RP_3GX 300 NO" [16Clnt_IORhard_3GX]="4 256 16 32 RP_3GX 300 NO"
            [1Sto4C_IOReasy_SX]="1 256 16 32 SX 60 NO" [1Sto4C_IORhard_SX]="1 256 16 32 SX 60 NO" 
            [1Sto4C_IOReasy_2GX]="2 256 16 32 RP_2GX 60 NO" [1Sto4C_IORhard_2GX]="2 256 16 32 RP_2GX 60 NO"
            [1Sto4C_IOReasy_3GX]="4 256 16 32 RP_3GX 60 NO" [1Sto4C_IORhard_3GX]="4 256 16 32 RP_3GX 60 NO" )

# MDT test suite
# Format:[<test name>]="min_servers max_servers num_targets num_ranks replication_type stonewall_timeout run/no_run"
MDT_suite=( [16Clnt_MDTeasy_SX]="1 256 16 32 SX 300 NO" [16Clnt_MDThard_SX]="1 256 16 32 SX 300 NO"
            [16Clnt_MDTeasy_2GX]="2 256 16 32 RP_2GX 300 NO" [16Clnt_MDThard_2GX]="2 256 16 32 RP_2GX 300 NO"
            [16Clnt_MDTeasy_3GX]="4 256 16 32 RP_3GX 300 NO" [16Clnt_MDThard_3GX]="4 256 16 32 RP_3GX 300 NO"
            [1Sto4C_MDTeasy_SX]="1 256 16 32 SX 60 NO" [1Sto4C_MDThard_SX]="1 256 16 32 SX 60 NO"
            [1Sto4C_MDTeasy_2GX]="2 256 16 32 RP_2GX 60 NO" [1Sto4C_MDThard_2GX]="2 256 16 32 RP_2GX 60 NO"
            [1Sto4C_MDTeasy_3GX]="4 256 16 32 RP_3GX 60 NO" [1Sto4C_MDThard_3GX]="4 256 16 32 RP_3GX 60 NO" )

# Set the needed PATH and LD_LIBRARY_PATH
export PATH=/opt/apps/xalt/xalt/bin:/opt/apps/intel19/python3/3.7.0/bin:/opt/apps/cmake/3.16.1/bin:/opt/apps/autotools/1.2/bin:/opt/apps/git/2.24.1/bin:/opt/intel/compilers_and_libraries_2019.5.281/linux/bin/intel64:/opt/apps/gcc/8.3.0/bin:/usr/lib64/qt-3.3/bin:/usr/local/bin:/bin:/usr/bin:/opt/ibutils/bin:/opt/ddn/ime/bin:/opt/dell/srvadmin/bin:.
export LD_LIBRARY_PATH=/opt/apps/intel19/python3/3.7.0/lib:/opt/intel/debugger_2019/libipt/intel64/lib:/opt/intel/compilers_and_libraries_2019.5.281/linux/daal/lib/intel64_lin:/opt/intel/compilers_and_libraries_2019.5.281/linux/tbb/lib/intel64_lin/gcc4.7:/opt/intel/compilers_and_libraries_2019.5.281/linux/mkl/lib/intel64_lin:/opt/intel/compilers_and_libraries_2019.5.281/linux/ipp/lib/intel64:/opt/intel/compilers_and_libraries_2019.5.281/linux/compiler/lib/intel64_lin:/opt/apps/gcc/8.3.0/lib64:/opt/apps/gcc/8.3.0/lib:/usr/lib64/:/usr/lib64/

# Define the location od daos, sacled testing, results. Extract the build identity as work week identity
DAOS_DIR="/work/06758/arunar/frontera/BUILDS/20WW33.3+eccd948/daos"
DST_DIR="/work/06758/arunar/frontera/TESTS/daos_scaled_testing"
RES_DIR="/work/06758/arunar/frontera/WEEKLY_RESULTS"
sub_str=${DAOS_DIR%/*}
if [[ -L "$sub_str" ]] ; then
    dir_str=`ls -la $dir_str | awk '{print $(NF)}'`
else
    dir_str=${sub_str##*/}
fi
BLD_DIR=${dir_str:0:8}

# Adjust the TIMEOUT tomaximum expected run time for any test
JOBNAME="scaletest"
TIMEOUT="2:00:00" #<hh:mm:ss>
EMAIL="aruna.ramanan@intel.com" #<first.last@intel.com>

SBPARAMS="-J $JOBNAME -t $TIMEOUT --mail-user=$EMAIL"

export DAOS_DIR
pushd $DST_DIR


# For each test config in the suite run the IOR tests doubling the number of servers each time from min to max servers
run_IOR () {
for  element in "${!IOR_suite[@]}"; do 

    export TESTCASE=$element
    export LOGS=$RES_DIR/$BLD_DIR/$TESTCASE
    echo $LOGS
    mkdir -p $LOGS

    # Extract the test caregory and IOR test type. 
    IFS='_' ; read -ra tcase <<<"$element" 
    test_type=${tcase[0]}
    ior_type=${tcase[1]}

    # Extract test config parameters
    config_str=${IOR_suite[$element]}
    IFS=' ' ; read -ra config <<<"$config_str" 
    min_servers=${config[0]}
    max_servers=${config[1]}
    targets=${config[2]}
    ranks=${config[3]}
    rep_type=${config[4]}
    sw_timeout=${config[5]}
    to_run=${config[6]}

    # If a test category is to be run, calculate the number of nodes and cores based on the test type
    # Set the desired partition to run in
    if [ "$to_run" = YES ] ; then
        servers=$min_servers
        while [ "$servers" -le "$max_servers" ] ; do
            if [ "$test_type" = "16Clnt" ] ; then
                num_nodes=$(( $servers+17 ))
                num_cores=$(( $num_nodes*56 ))
                clients=16
            else
                num_nodes=$(( 1+5*$servers ))
                num_cores=$(( $num_nodes*56 ))
                clients=$(( 4*$servers ))
            fi
            if [ "$num_nodes" -le 512 ] ; then
                partition="normal"
            else
                partition="large"
            fi
            echo Running $ior_type with nodes=$num_nodes cores=$num_cores under partition $partition
            sbatch $SBPARAMS -N $num_nodes  -n $num_cores -p $partition tests.sh $ior_type $servers $clients $targets $ranks $rep_type $sw_timeout
            servers=$(( 2*$servers ))
        done
    fi
done
}

# For each test config in the suite run the mdtest tests doubling the number of servers each time from min to max servers
run_MDT () {
for  element in "${!MDT_suite[@]}"; do 

    export TESTCASE=$element
    export LOGS=$RES_DIR/$BLD_DIR/$TESTCASE
    echo $LOGS
    mkdir -p $LOGS

    # Extract the test caregory and IOR test type. 
    IFS='_' ; read -ra tcase <<<"$element" 
    test_type=${tcase[0]}
    mdt_type=${tcase[1]}

    # Extract test config parameters
    config_str=${MDT_suite[$element]}
    IFS=' ' ; read -ra config <<<"$config_str" 
    min_servers=${config[0]}
    max_servers=${config[1]}
    targets=${config[2]}
    ranks=${config[3]}
    rep_type=${config[4]}
    sw_timeout=${config[5]}
    to_run=${config[6]}

    # If a test category is to be run, calculate the number of nodes and cores based on the test type
    # Set the desired partition to run in
    if [ "$to_run" = YES ] ; then
        servers=$min_servers
        while [ "$servers" -le "$max_servers" ] ; do
            if [ "$test_type" = "16Clnt" ] ; then
                num_nodes=$(( $servers+17 ))
                num_cores=$(( $num_nodes*56 ))
                clients=16
                num_files=12000
            else
                num_nodes=$(( 1+5*$servers ))
                num_cores=$(( $num_nodes*56 ))
                clients=$(( 4*$servers ))
                num_files=50000
            fi
            if [ "$num_nodes" -le 512 ] ; then
                partition="normal"
            else
                partition="large"
            fi
            echo Running $mdt_type with nodes=$num_nodes cores=$num_cores under partition $partition
            sbatch $SBPARAMS -N $num_nodes  -n $num_cores -p $partition tests.sh $mdt_type $servers $clients $targets $ranks $rep_type $sw_timeout $num_files
            servers=$(( 2*$servers ))
        done
    fi
done
}

# Run the cart self tests
run_SELF_TEST () {
export TESTCASE=run_st_1tomany_cli2srv_inf16
export LOGS=$RES_DIR/$(date +%Y%m%d)/$TESTCASE
mkdir -p $LOGS

sbatch $SBPARAMS -N 4 -n 4 -p normal tests.sh SELF_TEST 2 1 16
sbatch $SBPARAMS -N 6 -n 6 -p normal tests.sh SELF_TEST 4 1 16
sbatch $SBPARAMS -N 10 -n 10 -p normal tests.sh SELF_TEST 8 1 16
sbatch $SBPARAMS -N 18 -n 18 -p normal tests.sh SELF_TEST 16 1 16
sbatch $SBPARAMS -N 34 -n 34 -p normal tests.sh SELF_TEST 32 1 16
sbatch $SBPARAMS -N 66 -n 66 -p normal tests.sh SELF_TEST 64 1 16
sbatch $SBPARAMS -N 130 -n 130 -p normal tests.sh SELF_TEST 128 1 16 
sbatch $SBPARAMS -N 258 -n 258 -p normal tests.sh SELF_TEST 256 1 16
sbatch $SBPARAMS -N 514 -n 514 -p large tests.sh SELF_TEST 512 1 16

export TESTCASE=run_st_1tomany_cli2srv_inf1
export LOGS=$RES_DIR/$(date +%Y%m%d)/$TESTCASE
mkdir -p $LOGS

sbatch $SBPARAMS -N 4 -n 4 -p normal tests.sh SELF_TEST 2 1 1
sbatch $SBPARAMS -N 6 -n 6 -p normal tests.sh SELF_TEST 4 1 1
sbatch $SBPARAMS -N 10 -n 10 -p normal tests.sh SELF_TEST 8 1 1
sbatch $SBPARAMS -N 18 -n 18 -p normal tests.sh SELF_TEST 16 1 1
sbatch $SBPARAMS -N 34 -n 34 -p normal tests.sh SELF_TEST 32 1 1
sbatch $SBPARAMS -N 66 -n 66 -p normal tests.sh SELF_TEST 64 1 1
sbatch $SBPARAMS -N 130 -n 130 -p normal tests.sh SELF_TEST 128 1 1
sbatch $SBPARAMS -N 258 -n 258 -p normal tests.sh SELF_TEST 256 1 1
sbatch $SBPARAMS -N 514 -n 514 -p large tests.sh SELF_TEST 512 1 1
}

# Launch the desired tests
for  test in "${test_array[@]}"; do

    if [ "$test" == IOR ] ; then
        run_IOR 
    elif [ "$test" == MDT ] ; then
        run_MDT 
    elif [ "$test" == SELF_TEST ] ; then
        run_self_TEST
    else
        echo "No test to run"
    fi

done

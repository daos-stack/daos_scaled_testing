#!/bin/sh

export PATH=/opt/apps/xalt/xalt/bin:/opt/apps/intel19/python3/3.7.0/bin:/opt/apps/cmake/3.16.1/bin:/opt/apps/autotools/1.2/bin:/opt/apps/git/2.24.1/bin:/opt/intel/compilers_and_libraries_2019.5.281/linux/bin/intel64:/opt/apps/gcc/8.3.0/bin:/usr/lib64/qt-3.3/bin:/usr/local/bin:/bin:/usr/bin:/opt/ibutils/bin:/opt/ddn/ime/bin:/opt/dell/srvadmin/bin:.
export LD_LIBRARY_PATH=/opt/apps/intel19/python3/3.7.0/lib:/opt/intel/debugger_2019/libipt/intel64/lib:/opt/intel/compilers_and_libraries_2019.5.281/linux/daal/lib/intel64_lin:/opt/intel/compilers_and_libraries_2019.5.281/linux/tbb/lib/intel64_lin/gcc4.7:/opt/intel/compilers_and_libraries_2019.5.281/linux/mkl/lib/intel64_lin:/opt/intel/compilers_and_libraries_2019.5.281/linux/ipp/lib/intel64:/opt/intel/compilers_and_libraries_2019.5.281/linux/compiler/lib/intel64_lin:/opt/apps/gcc/8.3.0/lib64:/opt/apps/gcc/8.3.0/lib:/usr/lib64/:/usr/lib64/

DAOS_DIR="<path_to_daos>"
DST_DIR="<path_to_daos_scaled_testing>"
RES_DIR="<path_to_result_dir>"
JOBNAME="<sbatch_jobname>"
TIMEOUT="<sbatch_timeout>" #<hh:mm:ss>
EMAIL="<email>" #<first.last@intel.com>

SBPARAMS="-J $JOBNAME -t $TIMEOUT --mail-user=$EMAIL"

export DAOS_DIR
pushd $DST_DIR

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

#!/bin/sh

TEST="lfs_mpiio_lammps_impi"
echo "${TEST}"
echo
ps -ef | grep schan15
echo "Start Test"
echo
./run_${TEST}.sh | tee /panfs/users/schan15/client/results/${TEST}_noset.log
echo
echo

sleep 30

TEST="lfs_mpiio_lammps_mpich"
echo "${TEST}"
echo
ps -ef | grep schan15
echo "Start Test"
echo
./run_${TEST}.sh | tee /panfs/users/schan15/client/results/${TEST}_noset.log
echo
echo

sleep 30

TEST="lfs_fpp_lammps_impi"
echo "${TEST}"
echo
ps -ef | grep schan15
echo "Start Test"
echo
./run_${TEST}.sh | tee /panfs/users/schan15/client/results/${TEST}_noset.log
echo
echo

sleep 30

TEST="lfs_fpp_lammps_mpich"
echo "${TEST}"
echo
ps -ef | grep schan15
echo "Start Test"
echo
./run_${TEST}.sh | tee /panfs/users/schan15/client/results/${TEST}_noset.log
echo
echo

sleep 30

TEST="lfs_fpp_vpic_impi"
echo "${TEST}"
echo
ps -ef | grep schan15
echo "Start Test"
echo
./run_${TEST}.sh | tee /panfs/users/schan15/client/results/${TEST}_noset.log
echo
echo

sleep 30

TEST="lfs_fpp_vpic_mpich"
echo "${TEST}"
echo
ps -ef | grep schan15
echo "Start Test"
echo
./run_${TEST}.sh | tee /panfs/users/schan15/client/results/${TEST}_noset.log
echo
echo


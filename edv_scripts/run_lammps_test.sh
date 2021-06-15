#! /bin/bash

 . /opt/intel/impi/2021.2.0.215/setvars.sh

# Extract nodelist/hostfile
list=`squeue | grep ${USER} | grep -v Priority | awk '{print $1;exit}'`
hf="nodefile.${list}"
echo ${hf}
# Total clients from hostfile
cnodes=`wc -l ${hf} | awk '{print $1}'`
echo "Total nodes : ${cnodes}"
RUN_DIR=`pwd`

mkdir -p /daos/vishwana/lammps/

for i in 256
do
	for client in 1 2 4 8 16 32 64
	do
		rm -f /daos/vishwana/lammps/*
		ppn=$(( $i / $client ))
		mpiexec -n ${i} --hostfile ${hf} -ppn $ppn /panfs/users/vishwana/app_analysis/lammps/src/lmp_mpi -i /panfs/users/vishwana/app_analysis/lammps/bench/in.lj 2>&1 | tee lammps_result_${i}_${client}_${ppn}.out
	done
done

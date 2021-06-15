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

mkdir -p /daos/vishwana/vpic/

for i in 128 256
do
	for client in 1 2 4 8 16 32 64
	do
		echo -e "Start Cleaning...\n"
		rm -f /daos/vishwana/vpic/*
		echo -e "Done Cleaning..\n"
		ppn=$(( $i / $client ))
		set -x 
		mpiexec -n ${i} --hostfile ${hf} -ppn $ppn /panfs/users/vishwana/app_analysis/vpic-install/harris.Linux 2>&1 | tee vpic_result_${i}_${client}_${ppn}.out
		set +x 
	done
done

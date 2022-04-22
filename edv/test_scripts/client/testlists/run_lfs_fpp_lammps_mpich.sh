#/bin/sh

export TB="daos22"
export NODEFILE="/lfs/lfs12/${USER}/script/nodefile"
export INPUTFILE="/panfs/users/${USER}/client/input/in.lj.lfs.fpp"
export MPI="MPI"
export APPSRC="/panfs/users/${USER}/apps/${MPI}/lammps/src/lmp_mpi"
export MPIPATH="/panfs/users/${USER}/apps/latest_mpich" # not used for IMPI

if [[ "$MPI" =~ "IMPI" ]]; then
  . /opt/intel/impi/2021.2.0.215/setvars.sh --force
else
  export LD_LIBRARY_PATH=${MPIPATH}/lib:$LD_LIBRARY_PATH
  export PATH=${MPIPATH}/bin:$PATH
fi

source /panfs/users/${USER}/client/scripts/client_env.sh
export PATH=/usr/local/ofed/CURRENT/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/ofed/CURRENT/lib64:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/usr/local/ofed/CURRENT/lib64/libibverbs:$LD_LIBRARY_PATH


echo "********"
echo "Dump env"
echo "********"
env
echo
echo

echo "**********"
echo "Input file"
echo "**********"
ls -al /panfs/users/${USER}/apps/${MPI}/lammps
#cp /panfs/users/schan15/client/input/in.lj.lfs.fpp /panfs/users/schan15/apps/lammps/bench/in.lj
#cat /panfs/users/schan15/apps/lammps/bench/in.lj
cat ${INPUTFILE}
echo
echo

OUTDIR="/lfs/lfs12/${USER}/lammps"
echo "***************"
echo "Output dir info"
echo "***************"
rm -rf ${OUTDIR}
mkdir -p ${OUTDIR}
echo LAMMPS files before run
ls -al ${OUTDIR}
ls ${OUTDIR} | wc -l
echo Disk usage before run
du -sh ${OUTDIR}
echo

pwd
lfs setstripe -c -1 ${OUTDIR}

echo LFS getstripe
lfs getstripe ${OUTDIR}
echo
echo

echo "********"
echo "Run Test"
echo "********"
echo Which mpiexec
which mpiexec
if [[ ! "$MPI" =~ "IMPI" ]]; then
  ls -al ${MPIPATH}
fi
echo

echo "********"
echo "Nodelist"
echo "********"
echo "${NODEFILE}"
cat ${NODEFILE}

echo
echo
date
echo

ls -al ${APPSRC}
echo

echo "mpiexec -bootstrap ssh -n 1024 --hostfile ${NODEFILE} -ppn 64 ${APPSRC} -i ${INPUTFILE}"
mpiexec -bootstrap ssh -n 1024 --hostfile ${NODEFILE} -ppn 64 ${APPSRC} -i ${INPUTFILE} 2>&1

echo
echo
date
echo

echo "***************"
echo "Output dir info"
echo "***************"
echo LAMMPS files after run
ls -al ${OUTDIR}
ls ${OUTDIR} | wc -l
echo Disk usage after run
du -sh ${OUTDIR}
echo
echo
date
echo Remove files
rm -rf ${OUTDIR}
echo
date

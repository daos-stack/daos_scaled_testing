#/bin/sh

export TB="daos_rel201rc1"
export WW="22ww05"
export NODEFILE="/lfs/lfs12/schan15/scripts/nodefile"
export MPI="IMPI"
export MPIPATH="/panfs/users/schan15/apps/latest_mpich" # not used for IMPI
export APPSRC="/lfs/lfs12/schan15/efi_johann/bin/efispec3d_1.0_avx512_async.exe"
export APPDIR="/lfs/lfs12/schan15/efi_johann"
export INFILE="/panfs/users/schan15/client/input/e2vp2.cfg.big"
export OUTFILE="/panfs/users/schan15/client/results/e2vp2.lst.${MPI}.${WW}"

if [[ "$MPI" =~ "IMPI" ]]; then
  . /opt/intel/oneAPI/latest/setvars.sh
  . /opt/intel/impi/2021.2.0.215/setvars.sh --force
else
  export LD_LIBRARY_PATH=${MPIPATH}/lib:$LD_LIBRARY_PATH
  export PATH=${MPIPATH}/bin:$PATH
fi

source /panfs/users/schan15/client/scripts/client_env.sh
export PATH=/usr/local/ofed/CURRENT/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/ofed/CURRENT/lib64:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/usr/local/ofed/CURRENT/lib64/libibverbs:$LD_LIBRARY_PATH


echo "********"
echo "Dump env"
echo "********"
env
echo
echo

OUTDIR="/lfs/lfs12/schan15/efi_johann/test"
echo "***************"
echo "Input outdir info"
echo "***************"
rm -rf ${APPDIR}
echo "cp -r /panfs/users/schan15/apps/${MPI}/efi_johann /lfs/lfs12/schan15"
cp -r /panfs/users/schan15/apps/${MPI}/efi_johann /lfs/lfs12/schan15
cd ${OUTDIR}
cp ${INFILE} ${OUTDIR}/e2vp2.cfg
echo
cat ${OUTDIR}/e2vp2.cfg
echo
echo

echo "***************"
echo "Output dir info"
echo "***************"
echo EFISPEC files before run
ls -al ${OUTDIR}
ls ${OUTDIR} | wc -l
echo Disk usage before run
du -sh ${OUTDIR}
echo

pwd
lfs setstripe -c -1 ${OUTDIR}

echo LFS getstripe ${OUTDIR}
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

echo "mpiexec -bootstrap ssh -n 1024 --hostfile ${NODEFILE} -ppn 64 ${APPSRC}"
mpiexec -bootstrap ssh -n 1024 --hostfile ${NODEFILE} -ppn 64 ${APPSRC} 2>&1

echo
echo
date
echo

echo "***************"
echo "Output dir info"
echo "***************"
cp e2vp2.lst ${OUTFILE}
echo EFISPEC files after run
ls -al ${OUTDIR}
ls ${OUTDIR} | wc -l
echo Disk usage after run
du -sh ${OUTDIR}
echo
echo
date
echo Remove files
rm -rf ${APPDIR}
echo
date

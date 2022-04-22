#!/bin/sh

export SCM="700G" #700G
export NVME="30T" #1T

export SRV_HEADNODE="edaos11"
export MPI="MPI"
export MPIPATH="/panfs/users/rpadma2/apps/latest_mpich"
export RUNDIR="/panfs/users/rpadma2/client"
export BUILDDIR="/panfs/users/rpadma2/builds"
export TB="daos22"
export MOUNTDIR="/tmp/daos_m"
export APPSRC="/panfs/users/rpadma2/apps/${MPI}/lammps"
export APPNAME="lammps"
export APPRUNDIR="${APPSRC}"
export OUTDIR="${MOUNTDIR}/${APPNAME}"

export PPN=64
export MOUNT_DFUSE=1

cd $RUNDIR

export I_MPI_JOB_STARTUP_TIMEOUT=10800

#Run Test
export TYPE="mpiio" #fpp, mpiio, mpiiodfs
export APPINFILE="/panfs/users/rpadma2/client/input/in.lj.daos.${TYPE}"
export TESTCMD="${APPSRC}/src/lmp_mpi -i ${APPINFILE}"

if [[ "$TYPE" =~ "mpiiodfs" ]]; then
  export DFUSECACHE="--enable-caching" #FOR DFS
  export IL=0 #FOR DFS
  export ROMIO_FSTYPE_FORCE="daos:" #FOR DFS
else
  export DFUSECACHE="--disable-caching"
  export IL=1
  unset ROMIO_FSTYPE_FORCE
fi

export DFUSECACHE="--disable-caching"
export IL=1
export RF=2
export M=750
export TEST="${MPI}_LAMMPS_${TYPE}_${M}m_c16"
for n in {32,}
do
  export NSERVER="${n}"
  export NCLIENT="16"
  export RANKS="0-$((${NSERVER}-1))"
  export TESTDIR="${TEST}_${NSERVER}e_${NCLIENT}c_${PPN}ppn_RF${RF}_IL${IL}"
  export RESULTDIR="${RUNDIR}/results/${TESTDIR}"
  export RUNLOG="${TESTDIR}.log"

  rm -rf ${RESULTDIR}
  mkdir -p ${RESULTDIR}

  ${RUNDIR}/scripts/run_client.sh 2>&1 | tee ${RESULTDIR}/${RUNLOG}

  sleep 15
done

#sleep 15

#Run Test fpp
#export TYPE="fpp" #fpp, mpiio, mpiiodfs
#export APPINFILE="/panfs/users/rpadma2/client/input/in.lj.daos.${TYPE}"
#export TESTCMD="${APPSRC}/src/lmp_mpi -i ${APPINFILE}"
#
#if [[ "$TYPE" =~ "mpiiodfs" ]]; then
#  export DFUSECACHE="--enable-caching" #FOR DFS
#  export IL=0 #FOR DFS
#  export ROMIO_FSTYPE_FORCE="daos:" #FOR DFS
#else
#  export DFUSECACHE="--disable-caching"
#  export IL=1
#  unset ROMIO_FSTYPE_FORCE
#fi

#export RF=0
#export M=750
#export TEST="${MPI}_LAMMPS_${TYPE}_${M}m_c16"
#export NSERVER="32"
#export NCLIENT="16"
#export RANKS="0-$((${NSERVER}-1))"
#export TESTDIR="${TEST}_${NSERVER}e_${NCLIENT}c_${PPN}ppn_RF${RF}_IL${IL}"
#export RESULTDIR="${RUNDIR}/results/${TESTDIR}"
#export RUNLOG="${TESTDIR}.log"
#
#rm -rf ${RESULTDIR}
#mkdir -p ${RESULTDIR}
#
#${RUNDIR}/scripts/run_client.sh 2>&1 | tee ${RESULTDIR}/${RUNLOG}

#sleep 15
#
##Run Test dfs
#export TYPE="mpiiodfs" #fpp, mpiio, mpiiodfs
#export APPINFILE="/panfs/users/rpadma2/client/input/in.lj.daos.${TYPE}"
#export TESTCMD="${APPSRC}/src/lmp_mpi -i ${APPINFILE}"
#
#if [[ "$TYPE" =~ "mpiiodfs" ]]; then
#  export DFUSECACHE="--enable-caching" #FOR DFS
#  export IL=0 #FOR DFS
#  export ROMIO_FSTYPE_FORCE="daos:" #FOR DFS
#else
#  export DFUSECACHE="--disable-caching"
#  export IL=1
#  unset ROMIO_FSTYPE_FORCE
#fi
#
#export RF=0
#export M=750
#export TEST="${MPI}_LAMMPS_${TYPE}_${M}m_c16"
#export NSERVER="32"
#export NCLIENT="16"
#export RANKS="0-$((${NSERVER}-1))"
#export TESTDIR="${TEST}_${NSERVER}e_${NCLIENT}c_${PPN}ppn_RF${RF}_IL${IL}"
#export RESULTDIR="${RUNDIR}/results/${TESTDIR}"
#export RUNLOG="${TESTDIR}.log"
#
#rm -rf ${RESULTDIR}
#mkdir -p ${RESULTDIR}
#
#${RUNDIR}/scripts/run_client.sh 2>&1 | tee ${RESULTDIR}/${RUNLOG}


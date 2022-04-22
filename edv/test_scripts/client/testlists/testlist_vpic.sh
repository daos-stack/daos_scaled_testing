#!/bin/sh

export SCM="700G" #700G
export NVME="30T" #1T

export SRV_HEADNODE="edaos09"
export MPI="MPI"
export MPIPATH="/panfs/users/rpadma2/apps/latest_mpich"
export RUNDIR="/panfs/users/rpadma2/client"
export BUILDDIR="/panfs/users/rpadma2/builds"
export TB="daos22"
export MOUNTDIR="/tmp/daos_m"
export APPSRC="/panfs/users/rpadma2/apps/${MPI}/vpic/vpic-install/"
export APPNAME="vpic"
export APPRUNDIR="${APPSRC}"
export OUTDIR="${MOUNTDIR}/${APPNAME}"

export TESTCMD="${APPSRC}/harris.xl.daos.one_loop.Linux"

export PPN=64
export MOUNT_DFUSE=1

cd $RUNDIR

export I_MPI_JOB_STARTUP_TIMEOUT=18000

#FPP MPICH
export DFUSECACHE="--disable-caching"
unset ROMIO_FSTYPE_FORCE
export IL=1
export RF=0
export TEST="${MPI}_VPIC_FPP_${TB}_c16"
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


#IMPI
#export MPI="IMPI"
#export APPSRC="/panfs/users/rpadma2/apps/${MPI}/vpic/vpic-install/"
#export TESTCMD="${APPSRC}/harris.xl.daos.Linux"
#export TEST="${MPI}_VPIC_FPP_${TB}_c16"
#export DFUSECACHE="--disable-caching"
#unset ROMIO_FSTYPE_FORCE
#export IL=1
#export RF=0
#for n in {32,}
#do
#  export NSERVER="${n}"
#  export NCLIENT="16"
#  export RANKS="0-$((${NSERVER}-1))"
#  export TESTDIR="${TEST}_${NSERVER}e_${NCLIENT}c_${PPN}ppn_RF${RF}_IL${IL}"
#  export RESULTDIR="${RUNDIR}/results/${TESTDIR}"
#  export RUNLOG="${TESTDIR}.log"

#  rm -rf ${RESULTDIR}
#  mkdir -p ${RESULTDIR}

#  ${RUNDIR}/scripts/run_client.sh 2>&1 | tee ${RESULTDIR}/${RUNLOG}

#  sleep 15
#done

#!/bin/sh

export SCM="700G" #700G
export NVME="30T" #1T

export SRV_HEADNODE="edaos09"
export MPI="IMPI"
export RUNDIR="/panfs/users/schan15/client"
export BUILDDIR="/panfs/users/schan15/builds"
export TB="daos_rel201rc1"
export MOUNTDIR="/tmp/daos"
export APPSRC="/panfs/users/schan15/apps/${MPI}/efi_johann"
export APPNAME="efispec"
export APPRUNDIR="${MOUNTDIR}/efi_johann/test"
export OUTDIR="${MOUNTDIR}/efi_johann/test"
export APPINFILEDEST="${APPRUNDIR}"
export APPINFILE="/panfs/users/schan15/client/input/e2vp2.cfg.big"

export TESTCMD="${MOUNTDIR}/efi_johann/bin/efispec3d_1.0_avx512_async.exe"

export PPN=6 #64 for big
export MOUNT_DFUSE=1

cd $RUNDIR

export I_MPI_JOB_STARTUP_TIMEOUT=7200

#FPP
export DFUSECACHE="--disable-caching"
unset ROMIO_FSTYPE_FORCE
export IL=1
export RF=0
export TEST="${MPI}_EFISPEC_FPP_c16_noilstream"
export NSERVER="32"
export NCLIENT="16"
export RANKS="0-$((${NSERVER}-1))"
export TESTDIR="${TEST}_${NSERVER}e_${NCLIENT}c_${PPN}ppn_RF${RF}_IL${IL}"
export RESULTDIR="${RUNDIR}/results/${TESTDIR}"
export RUNLOG="${TESTDIR}.log"

rm -rf ${RESULTDIR}
mkdir -p ${RESULTDIR}

${RUNDIR}/scripts/run_client.sh 2>&1 | tee ${RESULTDIR}/${RUNLOG}

#sleep 15
#
#export DFUSECACHE="--enable-caching"
#unset ROMIO_FSTYPE_FORCE
#export IL=0
#export RF=0
#export TEST="${MPI}_EFISPEC_FPP_c16_noilstream"
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
#
#sleep 15


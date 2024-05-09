#!/bin/sh

# Get the common routines to parse command line
source ${RUNDIR}/testlists/testlist_common.sh

# Get the global environment variables
source ${RUNDIR}/scripts/client_env.sh

# Parse the command line
parseAndSetParameters $@ || exit

export SCM="700G" #700G
export NVME="30T" #1T

export SRV_HEADNODE="edaos09"
export MPI="IMPI"
export RUNDIR="/panfs/users/${USER}/client"
export BUILDDIR="/panfs/users/${USER}/builds"
export MOUNTDIR="/tmp/daos"
export APPSRC="/panfs/users/${USER}/apps/${MPI}/efi_johann"
export APPNAME="efispec"
export APPRUNDIR="${MOUNTDIR}/efi_johann/test"
export OUTDIR="${MOUNTDIR}/efi_johann/test"
export APPINFILEDEST="${APPRUNDIR}"
export APPINFILE="/panfs/users/${USER}/client/input/e2vp2.cfg.big"

export TESTCMD="${MOUNTDIR}/efi_johann/bin/efispec3d_1.0_avx512_async.exe"

export MOUNT_DFUSE=1

cd $RUNDIR

export I_MPI_JOB_STARTUP_TIMEOUT=7200

# EFISPEC always writes FPP
export DFUSECACHE="--disable-caching"
unset ROMIO_FSTYPE_FORCE
export TEST="${MPI}_EFISPEC_FPP"

# Remove commas from the comma separated list of servers
server_list=$(echo "$server_list" | sed 's/,/ /g')

for NSERVER in ${server_list}
do
  export NSERVER=$NSERVER
  export RANKS="0-$((${NSERVER}-1))"
  export TESTDIR="${TEST}_${NSERVER}e_${NCLIENT}c_${PPN}ppn_RF${RF}_IL${IL}"
  export RESULTDIR="${RUNDIR}/results/${TESTDIR}"
  export RUNLOG="${TESTDIR}.log"

  rm -rf ${RESULTDIR}
  mkdir -p ${RESULTDIR}

  ${RUNDIR}/scripts/run_client.sh 2>&1 | tee ${RESULTDIR}/${RUNLOG}

  sleep 15
done


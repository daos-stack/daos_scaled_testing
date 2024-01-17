#!/bin/sh

# Get the common routines to parse command line
source ${RUNDIR}/testlists/testlist_common.sh

# Get the global environment variables
source ${RUNDIR}/scripts/client_env.sh

# Parse the command line
parseAndSetParameters $@

export SCM="700G" #700G
export NVME="30T" #1T

export SRV_HEADNODE="edaos20"
export MPIPATH="/panfs/users/${USER}/apps/latest_mpich"
export RUNDIR="/panfs/users/${USER}/client"
export BUILDDIR="/panfs/users/${USER}/builds"
export MOUNTDIR="/tmp/daos_m"
export APPSRC="/panfs/users/${USER}/apps/${MPI}/vpic/vpic-install/"
export APPNAME="vpic"
export APPRUNDIR="${APPSRC}"
export OUTDIR="${MOUNTDIR}/${APPNAME}"

export TESTCMD="${APPSRC}/harris.xl.daos.Linux"

export MOUNT_DFUSE=1

export I_MPI_JOB_STARTUP_TIMEOUT=18000

#FPP MPICH
export DFUSECACHE="--disable-caching"
unset ROMIO_FSTYPE_FORCE

export TEST="${MPI}_${APPNAME}_${TB}"

cd $RUNDIR

# Remove commas from the comma separated lists of servers
server_list=$(echo "$server_list" | sed 's/,/ /g')

for NSERVER in ${server_list}
do
  export NSERVER=$NSERVER
  export RANKS="0-$((${NSERVER}-1))"
  export TESTDIR="${TEST}_${NSERVER}e_${NCLIENT}c_${PPN}ppn_${EC_CELL_SIZE}ec_${OCLASS}o_RF${RF}_IL${IL}"
  export RESULTDIR="${RUNDIR}/results/${TB}/${TESTDIR}"
  export RUNLOG="${TESTDIR}.log"

  rm -rf ${RESULTDIR}
  mkdir -p ${RESULTDIR}

  ${RUNDIR}/scripts/run_client.sh 2>&1 | tee ${RESULTDIR}/${RUNLOG}

  sleep 15
done


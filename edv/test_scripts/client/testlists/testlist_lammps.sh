#!/bin/sh

# Get the common routines to parse command line
source ${RUNDIR}/testlists/testlist_common.sh

# Get the global environment variables
source ${RUNDIR}/scripts/client_env.sh

# Parse the command line
parseAndSetParameters $@ || exit

export SCM="700G" #700G
export NVME="30T" #1T

export SRV_HEADNODE="edaos11"
export MPIPATH="/panfs/users/${USER}/apps/latest_mpich"
export RUNDIR="/panfs/users/${USER}/client"
export BUILDDIR="/panfs/users/${USER}/builds"
export MOUNTDIR="/tmp/daos_m"
export APPSRC="/panfs/users/${USER}/apps/${MPI}/lammps"
export APPNAME="lammps"
export APPRUNDIR="${APPSRC}"
export OUTDIR="${MOUNTDIR}/${APPNAME}"

export MOUNT_DFUSE=1

cd $RUNDIR

export I_MPI_JOB_STARTUP_TIMEOUT=10800

#Run Test
export APPINFILE="/panfs/users/rpadma2/client/input/in.lj.daos.${TYPE}"
export TESTCMD="${APPSRC}/src/lmp_mpi -i ${APPINFILE}"

if [[ "$TYPE" =~ "mpiiodfs" ]]; then
  export DFUSECACHE="--enable-caching" #FOR DFS
  export IL='' #FOR DFS
  export ROMIO_FSTYPE_FORCE="daos:" #FOR DFS
else
  export DFUSECACHE="--disable-caching"
  export IL=${il}
  unset ROMIO_FSTYPE_FORCE
fi

export M=750
export TEST="${MPI}_LAMMPS_${TYPE}_${M}m"

# Remove commas from the comma separated lists of servers
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


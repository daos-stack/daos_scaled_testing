#!/bin/sh

helpFunction()
{
   echo ""
   echo "Usage: $0 -s server_list -c clients -m mpi -b tb -r rf -i il -t mptype"
   echo -e "\t-s Server List (eg: 2,4,8,16,32)"
   echo -e "\t-c Total clients to use"
   echo -e "\t-m Type of MPI to use (MPI, IMPI)"
   echo -e "\t-b DAOS Test Build to use (eg: daos_xxx)"
   echo -e "\t-r DAOS Redundancy Factor(eg: rf=0,1,..)"
   echo -e "\t-i DAOS Interception library(eg: il=0,1)"
   echo -e "\t-t DAOS MPI Type(eg: mptype=fpp, mpiio, mpiiodfs)"
   exit 1 # Exit script after printing help
}

while getopts s:c:m:b:r:i:t: opt
do
   case ${opt} in
      s) server_list="$OPTARG" ;;
      c) clients="$OPTARG" ;;
      m) mpi="$OPTARG" ;;
      b) tb="$OPTARG" ;;
      r) rf="$OPTARG" ;;
      i) il="$OPTARG" ;;
      t) mptype="$OPTARG" ;;
      ?) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

[ -z $server_list ] && echo "Server List Argument Missing" && exit 1
[ -z $clients ] && echo "Number of Clients Argument Missing" && exit 1
[ -z $mpi ] && echo "MPI Argument Missing (MPI or IMPI)" && exit 1
[ -z $tb ] && echo "Test Build Argument Missing (eg: daos_xxx)" && exit 1
[ -z $rf ] && echo "DAOS Redundancy Argument Missing (eg: rf=0,1,..)" && exit 1
[ -z $il ] && echo "Intersection Library Argument Missing (eg: il=0,1)" && exit 1
[ -z $mptype ] && echo "MPI Type Argument Missing (eg: mptype=fpp,mpiio,mpiiodfs)" && exit 1

export SCM="700G" #700G
export NVME="30T" #1T

export SRV_HEADNODE="edaos11"
export MPI="${mpi}"
export MPIPATH="/panfs/users/rpadma2/apps/latest_mpich"
export RUNDIR="/panfs/users/rpadma2/client"
export BUILDDIR="/panfs/users/rpadma2/builds"
export TB="${tb}"
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
export TYPE="${mptype}" #fpp, mpiio, mpiiodfs
export APPINFILE="/panfs/users/rpadma2/client/input/in.lj.daos.${TYPE}"
export TESTCMD="${APPSRC}/src/lmp_mpi -i ${APPINFILE}"

if [[ "$TYPE" =~ "mpiiodfs" ]]; then
  export DFUSECACHE="--enable-caching" #FOR DFS
  export IL=0 #FOR DFS
  export ROMIO_FSTYPE_FORCE="daos:" #FOR DFS
else
  export DFUSECACHE="--disable-caching"
  export IL=${il}
  unset ROMIO_FSTYPE_FORCE
fi

export RF=${rf}
export M=750
export TEST="${MPI}_LAMMPS_${TYPE}_${M}m_c16"
for n in {${server_list},}
do
  export NSERVER="${n}"
  export NCLIENT="${clients}"
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


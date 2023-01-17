#!/bin/sh

helpFunction()
{
   echo ""
   echo "Usage: $0 -s server_list -c clients -p ppn -m mpi -b tb -r rf -i il -t mptype -d"
   echo -e "\t-s Server List (eg: 2,4,8,16,32)"
   echo -e "\t-c Total clients to use"
   echo -e "\t-p Number of processors per node (default=64)"
   echo -e "\t-m Type of MPI to use (MPI, IMPI)"
   echo -e "\t-b DAOS Test Build to use (eg: daos_xxx)"
   echo -e "\t-r DAOS Redundancy Factor(eg: rf=0,1,..)"
   echo -e "\t-i DAOS Interception library(eg: il=0,1)"
   echo -e "\t-t DAOS MPI Type(eg: mptype=fpp, mpiio, mpiiodfs)"
   echo -e "\t-d Trace application IO with Darshan [default=off]"
   exit 1 # Exit script after printing help
}

while getopts s:c:p:m:b:r:i:t:d opt
do
   case ${opt} in
      s) server_list="$OPTARG" ;;
      c) clients="$OPTARG" ;;
      p) ppn="$OPTARG" ;;
      m) mpi="$OPTARG" ;;
      b) tb="$OPTARG" ;;
      r) rf="$OPTARG" ;;
      i) il="$OPTARG" ;;
      t) mptype="$OPTARG" ;;
      d) darshan="1" ;;
      ?) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

[ -z $server_list ] && echo "Server List Argument Missing" && exit 1
[ -z $clients ] && echo "Number of Clients Argument Missing" && exit 1
[ -z $ppn ] && ppn=64
[ -z $mpi ] && echo "MPI Argument Missing (MPI or IMPI)" && exit 1
[ -z $tb ] && echo "Test Build Argument Missing (eg: daos_xxx)" && exit 1
[ -z $rf ] && echo "DAOS Redundancy Argument Missing (eg: rf=0,1,..)" && exit 1
[ -z $il ] && echo "Intersection Library Argument Missing (eg: il=0,1)" && exit 1
[ -z $mptype ] && echo "MPI Type Argument Missing (eg: mptype=fpp,mpiio,mpiiodfs" && exit 1
[ -z $darshan ] && darshan="0"

export SCM="700G" #700G
export NVME="30T" #1T

export SRV_HEADNODE="edaos09"
export MPI="${mpi}"
export MPIPATH="/panfs/users/${USER}/apps/latest_mpich"
export RUNDIR="/panfs/users/${USER}/client"
export BUILDDIR="/panfs/users/${USER}/builds"
export TB="${tb}"
export MOUNTDIR="/tmp/daos_m"
export APPSRC="/panfs/users/${USER}/apps/${MPI}/vpic/vpic-install/"
export APPNAME="vpic"
export APPRUNDIR="${APPSRC}"
export OUTDIR="${MOUNTDIR}/${APPNAME}"

export TESTCMD="${APPSRC}/harris.xl.daos.one_loop.Linux"

export PPN=${ppn}
export DARSHAN=${darshan}
export MOUNT_DFUSE=1

cd $RUNDIR

export I_MPI_JOB_STARTUP_TIMEOUT=18000

#FPP MPICH
export DFUSECACHE="--disable-caching"
unset ROMIO_FSTYPE_FORCE
export IL=$il
export RF=$rf
export TEST="${MPI}_VPIC_FPP_${TB}_c16"
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

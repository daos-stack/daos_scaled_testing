#!/bin/sh

# Help function for all testlist_* scripts
helpFunction()
{
  echo ""
  echo "Usage: $0 -d -s servers -c clients -p ppn -m mpi -t mptype -b tb -r rf -i il -e size -k chunk_size -o oclass -z start"
   echo -e "\t-d Collect Darshan logs"
   echo -e "\t-s Server List (eg: 2,4,8,16,32)"
   echo -e "\t-c Total clients to use"
   echo -e "\t-p Processes per node (default: 64)"
   echo -e "\t-m Type of MPI to use (MPI, IMPI)"
   echo -e "\t-b DAOS Test Build to use (eg: daos_xxx)"
   echo -e "\t-r DAOS Redundancy Factor(eg: rf=0,1,..)"
   echo -e "\t-i DAOS Interception library(eg: il=0,1)"
   echo -e "\t-e DAOS container property: cell size in bytes (eg: 1048576 for 1MB)"
   echo -e "\t-k DAOS container property: chunk size (eg: 4MB)"
   echo -e "\t-o DAOS container property: object class (oclass) (eg EC_4P2GX, EC_8P2GX)"
   echo -e "\t-t DAOS MPI Type(eg: mptype=FPP, MPIIO, MPIIODFS)"
   echo -e "\t-z Setup DAOS servers and clients (start_server, start_client), run application (app), or clean up (stop_client, stop_server)"

   exit 1 # Exit script after printing help
}

# Parse and set all common application environment variables
parseAndSetParameters()
{
  # Set default values
  DARSHAN="0"
  PPN=64
  EC_CELL_SIZE=''
  CHUNK_SIZE=''
  OCLASS=''
  RUNTYPE="all"

  # Parse the command line
  while getopts ds:c:p:m:b:i:r:t:e:k:o:z: opt
    do
      case ${opt} in
        d) DARSHAN="1" ;;
        s) server_list="$OPTARG" ;;
        c) NCLIENT="$OPTARG" ;;
        p) PPN="$OPTARG" ;;
        m) MPI="$OPTARG" ;;
        b) TB="$OPTARG" ;;
        r) RF="$OPTARG" ;;
        i) IL="$OPTARG" ;;
        e) EC_CELL_SIZE="$OPTARG" ;;
        k) CHUNK_SIZE="$OPTARG" ;;
        o) OCLASS="$OPTARG" ;;
        t) mptype="$OPTARG" ;;
        z) RUNTYPE="$OPTARG" ;;
        ?) helpFunction ;; # Print helpFunction in case parameter is non-existent
        esac
    done

  # Check that variable were provided
  [ -z $server_list ] && echo "List of servers argument missing" && exit 1
  [ -z $NCLIENT ] && echo "Number of Clients Argument Missing" && exit 1
  [ -z $MPI ] && echo "MPI Argument Missing (MPI or IMPI)" && exit 1
  [ -z $TB ] && echo "Test Build Argument Missing (eg: daos_xxx)" && exit 1
  [ -z $RF ] && echo "DAOS Redundancy Argument Missing (eg: rf=0,1,..)" && exit 1
  [ -z $IL ] && echo "Intersection Library Argument Missing (eg: il=0,1)" && exit 1
  [ -z $mptype ] && echo "MPI Type Argument Missing (eg: mptype=fpp,mpiio,mpiiodfs)" & exit 1

  # Export all variables. Individual scripts can over ride these varaibles
  export IL=$IL
  export PPN=$PPN
  export DARSHAN=$DARSHAN
  export server_list=$server_list
  export NCLIENT=$NCLIENT
  export MPI=$MPI
  export TB=$TB
  export RF=$RF
  export TYPE=$mptype
  export EC_CELL_SIZE=$EC_CELL_SIZE
  export CHUNK_SIZE=$CHUNK_SIZE
  export OCLASS=$OCLASS
  export RUNTYPE=$RUNTYPE
}

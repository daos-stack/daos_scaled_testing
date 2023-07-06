# daos_scaled_testing/edv
This directory contains DAOS setup and application execution scripts for the Intel cluster Endeavour.

## Usage
All scripts expect that the RUNDIR variable is set before any script is executed and that RUNDIR is the path to the client [directory]( https://github.com/daos-stack/daos_scaled_testing/tree/master/edv/test_scripts/client). For example, if the client directory is located at /panfs/users/janunez/, then we would set:
export RUNDIR=/panfs/users/janunez/client

Once the RUNDIR variable is set and applications are installed, you can run any of the applications using the scripts in the ($RUNDIR/testlists folder)[ https://github.com/daos-stack/daos_scaled_testing/tree/master/edv/test_scripts/client/testlists].
 
### Environment Variables
The RUNDIR variable is the only environment variable that is required to be set in your environment/command line. All other environment variables are found in $RUNDIR/scripts/client_env.sh and $RUNDIR/../server/srv_env.sh. Note that there are environment variables set in several other scripts, but we are working on moving them all into the client and server environment files. 

#### Environment Variables - client
The following variables are set inside the $RUNDIR/scripts/client_env.sh and can be changed to match your environment:
SRV_HEADNODE - master server node
CLI_HOSTLIST - Path to the client hostlist for use by clush and mpiexec/mpirun. 
SRVDIR - Path to the (server directory)[https://github.com/daos-stack/daos_scaled_testing/tree/master/edv/test_scripts/server]
DAOS_INSTALL - Path to DAOS installation directory
D_LOG_FILE - Path and name to DAOS client log file
DAOS_AGENT_DRPC_DIR - DAOS agent directory

#### Environment Variables - server
The following variables are set inside the $RUNDIR/../server/srv_env.sh and can be changed to match your environment:
export DAOS_INSTALL=/panfs/users/janunez/builds/$TB/install

## Organization
The Endeavour test scripts make assumptions on the location of scripts, hostfiles, applications and application input decks. The following are the expected location of directories/files and, if possible, how to change those expected locations. 

$RUNDIR - location of the scripts that setup, clean up and run applications on the DAOS client
$RUNDIR/../server - location of the scripts that setup, clean up and control the DAOS server
$RUNDIR/../apps - location of MPI and applications
$RUNDIR/../build - location of the DAOS build

## Running Applications
The scripts located in $RUNDIR/testlists contain the scripts to run applications. An example call to run LAMMPS is
./testlists/testlist_lammps.sh -d -s servers -c clients -p ppn -m mpi -t mptype -b tb -r rf -i il -e size -k chunk_size -o oclass -z start
where
        -d Collect Darshan logs
        -s Server List (eg: 2,4,8,16,32)
        -c Total clients to use
        -p Processes per node (default: 64)
        -m Type of MPI to use (MPI, IMPI)
        -b DAOS Test Build to use (eg: daos_xxx)
        -r DAOS Redundancy Factor(eg: rf=0,1,..)
        -i DAOS Interception library(eg: il=0,1)
        -e DAOS container property: cell size in bytes (eg: 1048576 for 1MB)
        -k DAOS container property: chunk size (eg: 4MB)
        -o DAOS container property: object class (oclass) (eg EC_4P2GX, EC_8P2GX)
        -t DAOS MPI Type(eg: mptype=FPP, MPIIO, MPIIODFS)
        -z Setup DAOS servers and clients (start_server, start_client), run application (app), or clean up (stop_client, stop_server)


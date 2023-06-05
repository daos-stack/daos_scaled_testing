#!/bin/sh

ulimit -c unlimited

export SWIM_PROTOCOL_PERIOD_LEN=2000
export SWIM_SUSPECT_TIMEOUT=19000
export SWIM_PING_TIMEOUT=1900

# Path to current DAOS installation
export DAOS_INSTALL=/panfs/users/${USER}/builds/$TB/install

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/ofed/CURRENT/lib64/libibverbs

# Explicitly set environment to work with Intel MPI
export FI_UNIVERSE_SIZE=16383
export FI_OFI_RXM_USE_SRX=1
export DAOS_BYPASS_DUNS=1
export DAOS_DISABLE_REQ_FWD=1
export FI_LOG_LEVEL=WARN

# Define paths to binaries, libraries and header files
export PATH=${DAOS_INSTALL}/bin:$PATH
export LD_LIBRARY_PATH=${DAOS_INSTALL}/lib64:${DAOS_INSTALL}/lib:$LD_LIBRARY_PATH
export CPATH=${DAOS_INSTALL}/include:$CPATH

# Use crt's fuse libraries since CentOS8 has a very old version
export PATH=/opt/crtdc/fuse3/bin:$PATH
export LD_LIBRARY_PATH=/opt/crtdc/fuse3/lib64:$LD_LIBRARY_PATH

daospath=/$DAOS_INSTALL
prereqpath=/$DAOS_INSTALL/prereq/release

PATH=${prereqpath}/argobots/bin:$PATH
PATH=${prereqpath}/isal/bin:$PATH
PATH=${prereqpath}/isal_crypto/bin:$PATH
PATH=${prereqpath}/mercury/bin:$PATH
PATH=${prereqpath}/ofi/bin:$PATH
PATH=${prereqpath}/openpa/bin:$PATH
PATH=${prereqpath}/pmdk/bin:$PATH
PATH=${prereqpath}/protobufc/bin:$PATH
PATH=${prereqpath}/psm2/bin:$PATH
PATH=${prereqpath}/spdk/bin:$PATH
PATH=${daospath}/bin/:$PATH

LD_LIBRARY_PATH=${prereqpath}/argobots/lib:$LD_LIBRARY_PATH
LD_LIBRARY_PATH=${prereqpath}/isal/lib:$LD_LIBRARY_PATH
LD_LIBRARY_PATH=${prereqpath}/isal_crypto/lib:$LD_LIBRARY_PATH
LD_LIBRARY_PATH=${prereqpath}/mercury/lib:$LD_LIBRARY_PATH
LD_LIBRARY_PATH=${prereqpath}/ofi/lib:$LD_LIBRARY_PATH
LD_LIBRARY_PATH=${prereqpath}/openpa/lib:$LD_LIBRARY_PATH
LD_LIBRARY_PATH=${prereqpath}/pmdk/lib:$LD_LIBRARY_PATH
LD_LIBRARY_PATH=${prereqpath}/protobufc/lib:$LD_LIBRARY_PATH
LD_LIBRARY_PATH=${prereqpath}/psm2/lib64:$LD_LIBRARY_PATH
LD_LIBRARY_PATH=${prereqpath}/spdk/lib:$LD_LIBRARY_PATH
LD_LIBRARY_PATH=${daospath}/lib64/:${daospath}/lib/:$LD_LIBRARY_PATH
LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib64/

export CPATH=${daospath}/include/:$CPATH

# FUSE3
export PATH=/opt/crtdc/fuse3/bin:$PATH
export LD_LIBRARY_PATH=/opt/crtdc/fuse3/lib64:$LD_LIBRARY_PATH

# OFED
export PATH=/usr/local/ofed/mlnx-5.1-2.5.8.0-1160.6.1-2.12.5/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/ofed/mlnx-5.1-2.5.8.0-1160.6.1-2.12.5/lib64:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/usr/local/ofed/mlnx-5.1-2.5.8.0-1160.6.1-2.12.5/lib64/libibverbs:$LD_LIBRARY_PATH
export CPATH=/usr/local/ofed/mlnx-5.1-2.5.8.0-1160.6.1-2.12.5/include:$CPATH


#!/bin/bash

export BUILD_DIR="<path_build_area>" #e.g./scratch/POC/BUILDS/
export IOR_DIR="<path_to_ior_repo>" #e.g./scratch/POC/ior-hpc
export MPICH_DIR="<path_to_mpich>" #e.g./scratch/POC/mpich
export OPENMPI_DIR="<path_to_openmpi>" #e.g./scratch/POC/openmpi

# Unload modules that are not needed on Frontera
module unload impi pmix hwloc
module list

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LATEST_DAOS=${BUILD_DIR}/latest/daos/install
folder=$(date +%Y%m%d)

source ${CURRENT_DIR}/build_env.sh openmpi

declare -a PRECIOUS_FILES=("bin/daos"
                           "bin/daos_server"
                           "bin/daos_agent"
                           "bin/dmg"
                           "ior${MPI_SUFFIX}/bin/ior"
                           "ior${MPI_SUFFIX}/bin/mdtest"
                           )

function check_target_files_exist() {
  for i in "${PRECIOUS_FILES[@]}"
  do
    CURRENT_FILE=${LATEST_DAOS}/${i}

    if [ ! -f ${CURRENT_FILE} ]; then
      echo "Error: missing file ${CURRENT_FILE}"
      exit 1
    fi
  done
}

function check_daos_linkage() {
  if ! ldd ${1} | grep -q libdaos.so ; then
    echo "Error: file ${1} does not link DAOS libraries"
    exit 1
  fi
}

function check_retcode(){
  exit_code=${1}
  last_command=${2}

  if [ ${exit_code} -ne 0 ]; then
    echo "${last_command} command failed with exit code ${exit_code}."
    exit ${exit_code}
  fi
}
trap 'check_retcode $? ${BASH_COMMAND}' EXIT
set -e

rm -rf $BUILD_DIR/$folder
mkdir -p $BUILD_DIR/$folder

pushd $BUILD_DIR/
rm -f latest
ln -s $BUILD_DIR/$folder latest
pushd latest
git clone https://github.com/daos-stack/daos.git
pushd daos
git submodule init
git submodule update
git merge --no-edit origin/tanabarr/control-no-ipmctl-May2020
git merge --no-edit origin/mjmac/allow-fwd-disable-20200508
scons MPI_PKG=any --build-deps=yes --config=force install
popd
popd
popd



pushd $IOR_DIR
./bootstrap
./configure --prefix=${LATEST_DAOS}/ior${MPI_SUFFIX} \
            --with-daos=${LATEST_DAOS} \
            --with-cart=${LATEST_DAOS} \
            CPPFLAGS=-I${LATEST_DAOS}/prereq/dev/mercury/include \
            LIBS=-lmpi
make clean
make
make install
popd

# Perform a basic revision of the built binaries
check_target_files_exist
check_daos_linkage ${LATEST_DAOS}/ior${MPI_SUFFIX}/bin/ior
check_daos_linkage ${LATEST_DAOS}/ior${MPI_SUFFIX}/bin/mdtest

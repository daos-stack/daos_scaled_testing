#!/bin/bash

export BUILD_DIR="<path_build_area>" #e.g./scratch/POC/BUILDS/
export IOR_DIR="<path_to_ior_repo>" #e.g./scratch/POC/ior-hpc

# Unload modules that are not needed on Frontera
module unload impi pmix hwloc
module list

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LATEST_DAOS=${BUILD_DIR}/latest/daos/install
folder=$(date +%Y%m%d)

source ${CURRENT_DIR}/source_me.sh openmpi

declare -a PRECIOUS_FILES=("bin/daos"
                           "bin/daos_server"
                           "bin/daos_agent"
                           "bin/dmg"
                           "ior${MPI_SUFFIX}/bin/ior"
                           "ior${MPI_SUFFIX}/bin/mdtest"
                           )

function basic_check() {
  for i in "${PRECIOUS_FILES[@]}"
  do
    CURRENT_FILE=${LATEST_DAOS}/${i}

    if [ ! -f ${CURRENT_FILE} ]; then
      echo "Error: missing file ${CURRENT_FILE}"
      exit 1
    fi

    if ! ldd ${CURRENT_FILE} | grep -q daos ; then
      echo "Error: file ${CURRENT_FILE} does not link DAOS libraries"
      exit 1
    fi
  done
}

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
basic_check ${LATEST_DAOS}/ior${MPI_SUFFIX}/bin/ior

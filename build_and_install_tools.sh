#!/bin/bash

if [ $# -gt 0 ]; then
    echo "Usage: $(basename $0)"
    echo "Build and install some prerequisite packages."
    exit 1
fi

BUILD_DIR=${SCRATCH}/BUILDS
INSTALL_DIR=${HOME}/TOOLS

# Unload modules that are not needed on Frontera
module unload impi pmix hwloc intel python3
module list

mkdir -p ${BUILD_DIR}
mkdir -p ${INSTALL_DIR}

pushd ${BUILD_DIR}


echo "===== Building hwloc ====="
wget https://download.open-mpi.org/release/hwloc/v1.11/hwloc-1.11.5.tar.bz2
tar -xvf hwloc-1.11.5.tar.bz2
pushd ${BUILD_DIR}/hwloc-1.11.5
./configure --prefix=${INSTALL_DIR}/hwloc
make
make install
popd


echo "===== Building openmpi ====="
wget https://download.open-mpi.org/release/open-mpi/v3.1/openmpi-3.1.3.tar.bz2
tar -xvf openmpi-3.1.3.tar.bz2
pushd ${BUILD_DIR}/openmpi-3.1.3
./configure --prefix=${INSTALL_DIR}/openmpi --with-hwloc=${INSTALL_DIR}/hwloc
make
make install
popd


echo "===== Building mpich ====="
wget http://www.mpich.org/static/downloads/3.3.2/mpich-3.3.2.tar.gz
tar -xvf mpich-3.3.2.tar.gz
pushd ${BUILD_DIR}/mpich-3.3.2
./autogen.sh
./configure --prefix=${INSTALL_DIR}/mpich --enable-fortran=all --enable-romio \
            --enable-cxx --enable-fast --disable-error-checking \
            --without-timing --with-file-system=ufs --with-device=ch3:nemesis
make
make install
popd


popd


echo "===== Done ====="


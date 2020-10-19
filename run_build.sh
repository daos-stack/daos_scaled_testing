#!/bin/bash

export BUILD_DIR="<path_build_area>" #e.g./scratch/POC/BUILDS/
export IOR_DIR="<path_to_ior_repo>" #e.g./scratch/POC/ior-hpc
export MPI_DIR="<path_to_mpi>" #e.g./scratch/POC/mpi

# Unload modules that are not needed on Frontera
module unload impi pmix hwloc
module list

folder=$(date +%Y%m%d)
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
scons --build-deps=yes --config=force install
popd
popd
popd

pushd $IOR_DIR
./bootstrap
./configure --prefix=$BUILD_DIR/latest/daos/install/ior_openmpi --with-daos=$BUILD_DIR/latest/daos/install --with-cart=$BUILD_DIR/latest/daos/install MPICC=$MPI_DIR/bin/mpicc CPPFLAGS="-I$BUILD_DIR/latest/daos/install/prereq/dev/mercury/include -I$MPI_DIR/include" LDFLAGS=-L$MPI_DIR/lib LIBS=-lmpi
make clean
make
make install
popd

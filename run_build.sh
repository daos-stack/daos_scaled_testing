#!/bin/bash

export BUILD_DIR=/home1/06753/soychan/work/POC/BUILDS/

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

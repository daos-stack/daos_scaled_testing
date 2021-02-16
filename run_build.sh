#!/bin/bash

export BUILD_DIR="<path_build_area>" #e.g./scratch/POC/BUILDS/
export MPICH_DIR="<path_to_mpich>" #e.g./scratch/POC/mpich
export OPENMPI_DIR="<path_to_openmpi>" #e.g./scratch/POC/openmpi

# Unload modules that are not needed on Frontera
module unload impi pmix hwloc
module list

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TIMESTAMP=$(date +%Y%m%d)
LATEST_DAOS=${BUILD_DIR}/${TIMESTAMP}/daos/install

export PATH=~/.local/bin:$PATH
export PYTHONPATH=$PYTHONPATH:~/.local/lib

source ${CURRENT_DIR}/build_env.sh openmpi

declare -a PRECIOUS_FILES=("bin/daos"
                           "bin/daos_server"
                           "bin/daos_agent"
                           "bin/dmg"
                           "ior${MPI_SUFFIX}/bin/${IOR_BIN}"
                           "ior${MPI_SUFFIX}/bin/${MDTEST_BIN}"
                           )

# List of development or test branches to be merged on top of DAOS
# master branch
declare -a DAOS_PATCHES=("origin/tanabarr/control-no-ipmctl-May2020"
                         "origin/mjmac/io500-frontera"
                         )

function merge_extra_daos_branches() {
  for PATCH in "${DAOS_PATCHES[@]}"
  do
    echo "Merging branch: ${PATCH}"
    git log ${PATCH} | head -n 1
    git merge --no-edit ${PATCH}
    echo
  done
}

function print_repo_info() {
  REPO_NAME=$(git remote -v | head -n 1 | cut -d $'\t' -f 2 | cut -d " " -f 1)
  printf '%80s\n' | tr ' ' =
  echo "Repo: ${REPO_NAME}"
  git log | head -n 1
  echo
}

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

rm -rf ${BUILD_DIR}/${TIMESTAMP}
mkdir -p ${BUILD_DIR}/${TIMESTAMP}

pushd $BUILD_DIR/
rm -f latest
ln -s ${BUILD_DIR}/${TIMESTAMP} latest
pushd ${BUILD_DIR}/${TIMESTAMP}
git clone https://github.com/daos-stack/daos.git
pushd daos
git submodule init
git submodule update
print_repo_info |& tee -a ${BUILD_DIR}/${TIMESTAMP}/repo_info.txt
merge_extra_daos_branches |& tee -a ${BUILD_DIR}/${TIMESTAMP}/repo_info.txt
scons MPI_PKG=any --build-deps=yes --config=force BUILD_TYPE=release install
popd
popd
popd


# Build IOR/MDTEST

pushd ${BUILD_DIR}/${TIMESTAMP}
git clone https://github.com/hpc/ior.git
pushd ${BUILD_DIR}/${TIMESTAMP}/ior

print_repo_info |& tee -a ${BUILD_DIR}/${TIMESTAMP}/repo_info.txt
./bootstrap
./configure --prefix=${LATEST_DAOS}/ior${MPI_SUFFIX} \
            MPICC=${MPI_BIN}/mpicc \
            --with-daos=${LATEST_DAOS} \
            CPPFLAGS=-I${LATEST_DAOS}/prereq/release/mercury/include \
            LIBS=-lmpi
make clean
make
make install

pushd ${LATEST_DAOS}/ior${MPI_SUFFIX}/bin
mv -v ior ${IOR_BIN}
mv -v mdtest ${MDTEST_BIN}
popd

popd
popd

# Perform a basic revision of the built binaries
check_target_files_exist
check_daos_linkage ${LATEST_DAOS}/ior${MPI_SUFFIX}/bin/${IOR_BIN}
check_daos_linkage ${LATEST_DAOS}/ior${MPI_SUFFIX}/bin/${MDTEST_BIN}

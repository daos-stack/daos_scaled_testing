#!/bin/bash

# Extra arguments to pass to DAOS scons
EXTRA_BUILD="${1}"

export BUILD_DIR="<path_build_area>"   # e.g. $WORK2/BUILDS/
export MPICH_DIR="<path_to_mpich>"     # e.g. /scratch/POC/mpich
export OPENMPI_DIR="<path_to_openmpi>" # e.g. /scratch/POC/openmpi

# DAOS branch to clone
DAOS_BRANCH="master"

# Optional DAOS commit to checkout after clone
DAOS_COMMIT=""

# Optional DAOS branches to merge
DAOS_BRANCHES=()

# Optional DAOS commits to cherry-pick
DAOS_CHERRY=()

# DAOS scons build type
DAOS_BUILD_TYPE="release"

# MPI to build DAOS with
MPI_TARGET="mvapich2"

# Optional IOR commit to checkout after clone
IOR_COMMIT=""

# Unload modules that are not needed on Frontera
module unload impi pmix hwloc
module list

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TIMESTAMP=$(date +%Y%m%d)
LATEST_DAOS=${BUILD_DIR}/${TIMESTAMP}/daos/install

export PATH=~/.local/bin:$PATH
export PYTHONPATH=$PYTHONPATH:~/.local/lib

source ${CURRENT_DIR}/build_env.sh ${MPI_TARGET}

declare -a PRECIOUS_FILES=("bin/daos"
                           "bin/daos_server"
                           "bin/daos_agent"
                           "bin/dmg"
                           "ior${MPI_SUFFIX}/bin/${IOR_BIN}"
                           "ior${MPI_SUFFIX}/bin/${MDTEST_BIN}"
                           )

# Extra branches needed for DAOS to work on frontera
if [ "${DAOS_BRANCH}" == "release/1.2" ]; then
    # Need to use the older branch
    declare -a DAOS_PATCHES=(
                             "origin/mjmac/io500-frontera"
                             )
else
    # Use the newer branch
    declare -a DAOS_PATCHES=(
                             "origin/dbohninx-io500-base-daaf038"
                             )
fi

# Also merge user-provided branches
DAOS_PATCHES+=( "${DAOS_BRANCHES[@]}" )

function merge_extra_daos_branches() {
  for PATCH in "${DAOS_PATCHES[@]}"
  do
    echo "Merging branch: ${PATCH}"
    git log -n 1 --pretty=format:"commit %H%n" "${PATCH}" || return
    git merge --no-edit ${PATCH} || return
    echo
  done
}

function cherry_pick_daos_commits() {
  for COMMIT in "${DAOS_CHERRY[@]}"
  do
    echo "Cherry-picking commit: ${COMMIT}"
    git log -n 1 --pretty=format:"commit %H%n" "${COMMIT}" || return
    git cherry-pick --no-edit ${COMMIT} || return
    echo
  done
}

function print_repo_info() {
  REPO_NAME=$(git remote -v | head -n 1 | cut -d $'\t' -f 2 | cut -d " " -f 1)
  printf '%80s\n' | tr ' ' =
  echo "Repo: ${REPO_NAME}"
  git log -n 1 --pretty=format:"commit %H%n"
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

function install_python_deps() {
    echo "Installing python build dependencies"
    cmd="python3 -m pip install --user --upgrade pip"
    echo ${cmd}
    eval ${cmd} || return
    cmd="python3 -m pip install --user --ignore-installed distro scons"
    echo ${cmd}
    eval ${cmd} || return
    # Hack because scons doesn't propagate the environment
    cmd="/usr/bin/python3 -m pip install --user --upgrade pip"
    echo ${cmd}
    eval ${cmd} || return
    cmd="/usr/bin/python3 -m pip install --user --ignore-installed pyelftools"
    echo ${cmd}
    eval ${cmd} || return
}

# Exit if any command fails
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
set -o pipefail

install_python_deps

rm -rf ${BUILD_DIR}/${TIMESTAMP}
mkdir -p ${BUILD_DIR}/${TIMESTAMP}

pushd $BUILD_DIR/
rm -f latest
ln -s ${BUILD_DIR}/${TIMESTAMP} latest
pushd ${BUILD_DIR}/${TIMESTAMP}
git clone https://github.com/daos-stack/daos.git -b "${DAOS_BRANCH}"
pushd daos
if [ ! -z "${DAOS_COMMIT}" ]; then
    git checkout -b "${DAOS_COMMIT}" "${DAOS_COMMIT}"
fi
git submodule init
git submodule update
print_repo_info |& tee -a ${BUILD_DIR}/${TIMESTAMP}/repo_info.txt
merge_extra_daos_branches |& tee -a ${BUILD_DIR}/${TIMESTAMP}/repo_info.txt
cherry_pick_daos_commits |& tee -a ${BUILD_DIR}/${TIMESTAMP}/repo_info.txt
scons MPI_PKG=any \
      --build-deps=yes \
      --config=force \
      BUILD_TYPE=${DAOS_BUILD_TYPE} \
      install ${EXTRA_BUILD}
popd
popd
popd


# Build IOR/MDTEST

pushd ${BUILD_DIR}/${TIMESTAMP}
git clone https://github.com/hpc/ior.git
pushd ${BUILD_DIR}/${TIMESTAMP}/ior
if [ ! -z "${IOR_COMMIT}" ]; then
    git checkout -b "${IOR_COMMIT}" "${IOR_COMMIT}"
fi

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

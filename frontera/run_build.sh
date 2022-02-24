#!/bin/bash
#
# Build DAOS locally.
#

# Default params
BUILD_DIR="${WORK}/BUILDS/"
TIMESTAMP=$(date +%Y%m%d)
DAOS_BRANCH="master"
DAOS_COMMIT=""
EXTRA_DAOS_BRANCHES=()
EXTRA_DAOS_CHERRY=()
DAOS_BUILD_TYPE="release"
MPI_TARGET="mvapich2"
IOR_COMMIT=""
SCONS_BUILD_DEPS="yes"
SCONS_EXTRA_ARGS=""
export MPICH_DIR="${WORK}/TOOLS/mpich"
export OPENMPI_DIR="${WORK}/TOOLS/openmpi"

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h)
      echo "Usage: $0"
      echo ""
      echo "  --build-dir=${BUILD_DIR}"
      echo "    Directory to build in"
      echo ""
      echo "  --timestamp=${TIMESTAMP}"
      echo "    Build will be in <build-dir>/<timestamp>"
      echo "    **To be improved**"
      echo ""
      echo "  --daos-branch=${DAOS_BRANCH}"
      echo "    DAOS branch to clone"
      echo ""
      echo "  --daos-commit=${DAOS_COMMIT}"
      echo "    Optional DAOS commit to checkout after clone"
      echo ""
      echo "  --extra-daos-branches=${EXTRA_DAOS_BRANCHES}"
      echo "    Optional DAOS branches to merge"
      echo ""
      echo "  --extra-daos-cherry=${EXTRA_DAOS_CHERRY}"
      echo "    Optional DAOS commits to cherry-pick"
      echo ""
      echo "  --daos-build-type=${DAOS_BUILD_TYPE}"
      echo "    DAOS scons build type"
      echo ""
      echo "  --mpi-target=${MPI_TARGET}"
      echo "    MPI to build DAOS and ior with"
      echo ""
      echo "  --ior-commit=${IOR_COMMIT}"
      echo "    Optional IOR commit to checkout after clone"
      echo ""
      echo "  --mpich-dir=${MPICH_DIR}"
      echo "    Path to locally built MPICH, if MPI-TARGET=mpich"
      echo ""
      echo "  --openmpi-dir=${OPENMPI_DIR}"
      echo "    Path to locally built OPENMPI, if MPI-TARGET=openmpi"
      echo ""
      echo "  --scons-build-deps=${SCONS_BUILD_DEPS}"
      echo "    Whether DAOS scons should build dependencies"
      echo ""
      echo "  --scons-extra-args=${SCONS_EXTRA_ARGS}"
      echo "    Optional args to pass to DAOS scons"
      exit 0
      ;;
    --build-dir*|-d*) if [[ "$1" != *=* ]]; then shift; fi
      BUILD_DIR="${1#*=}";;
    --daos-branch*|-b*) if [[ "$1" != *=* ]]; then shift; fi
      DAOS_BRANCH="${1#*=}";;
    --daos-commit*) if [[ "$1" != *=* ]]; then shift; fi
      DAOS_COMMIT="${1#*=}";;
    --extra-daos-branches*) if [[ "$1" != *=* ]]; then shift; fi
      EXTRA_DAOS_BRANCHES=(${1#*=});;
    --extra-daos-cherry*) if [[ "$1" != *=* ]]; then shift; fi
      EXTRA_DAOS_CHERRY=(${1#*=});;
    --daos-build-type*) if [[ "$1" != *=* ]]; then shift; fi
      DAOS_BUILD_TYPE="${1#*=}";;
    --mpi-target*) if [[ "$1" != *=* ]]; then shift; fi
      MPI_TARGET="${1#*=}";;
    --ior-commit*) if [[ "$1" != *=* ]]; then shift; fi
      IOR_COMMIT="${1#*=}";;
    --mpich-dir*) if [[ "$1" != *=* ]]; then shift; fi
      export MPICH_DIR="${1#*=}";;
    --openmpi-dir*) if [[ "$1" != *=* ]]; then shift; fi
      export OPENMPI_DIR="${1#*=}";;
    --scons-extra-args*) if [[ "$1" != *=* ]]; then shift; fi
      SCONS_EXTRA_ARGS="${1#*=}";;
    *)
      >&2 printf "Invalid argument: $1\n"
      exit 1
      ;;
  esac
  shift
done

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LATEST_DAOS=${BUILD_DIR}/${TIMESTAMP}/daos/install

# Setup the environment
function setup_env() {
  module unload impi pmix hwloc || return
  export PATH=~/.local/bin:$PATH
  export PYTHONPATH=$PYTHONPATH:~/.local/lib
  source ${CURRENT_DIR}/build_env.sh ${MPI_TARGET} || return
  module list || return
}

# Check if git HEAD contains a specified commit
function git_has_commit() {
  local commit=$1
  if git merge-base --is-ancestor "${commit}" $(git symbolic-ref --short HEAD); then
    echo true
  else
    echo false
  fi
}

# Merge a "hack" branch and user-specified branches
function merge_extra_daos_branches() {
  local hack_branch=""
  if $(git_has_commit "0fd0d78") = true; then
    hack_branch="origin/dbohning-io500-base-0fd0d78"
  elif $(git_has_commit "1c9fbac") = true; then
    hack_branch="origin/dbohning-io500-base-1c9fbac"
  elif $(git_has_commit "1650544") = true; then
    hack_branch="origin/dbohning-io500-base-1650544-2.0"
  elif $(git_has_commit "f15d6c9") = true; then
    hack_branch="origin/dbohning-io500-base-f15d6c9"
  elif $(git_has_commit "b7a8e51") = true; then
    hack_branch="origin/dbohning-io500-base-b7a8e51-2.0"
  elif $(git_has_commit "3e37280") = true; then
    hack_branch="origin/dbohning-io500-base-3e37280"
  elif $(git_has_commit "af19e7f") = true; then
    hack_branch="origin/dbohning-io500-base-af19e7f"
  elif $(git_has_commit "40f8636") = true; then
    hack_branch="origin/dbohning-io500-base-40f8636"
  elif $(git_has_commit "daaf038") = true; then
    hack_branch="origin/dbohning-io500-base-daaf038"
  else
    hack_branch="origin/mjmac/io500-frontera"
  fi;

  # Add the hack branch to the user-specified branches
  EXTRA_DAOS_BRANCHES+=("${hack_branch}")

  for PATCH in "${EXTRA_DAOS_BRANCHES[@]}"
  do
    echo "Merging branch: ${PATCH}"
    git log -n 1 --pretty=format:"commit %H%n" "${PATCH}" || return
    git merge --no-edit ${PATCH} || return
    echo
  done
}

function cherry_pick_daos_commits() {
  for COMMIT in "${EXTRA_DAOS_CHERRY[@]}"
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

# Setup a new build directory, removing if it already exists
function setup_build_dir() {
  rm -rf ${BUILD_DIR}/${TIMESTAMP}
  mkdir -p ${BUILD_DIR}/${TIMESTAMP}
  rm -f ${BUILD_DIR}/latest
  ln -s ${BUILD_DIR}/${TIMESTAMP} ${BUILD_DIR}/latest
}

# Clone, checkout, and merge DAOS branches
function clone_daos() {
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
  popd
  popd
}

# Build DAOS
function build_daos() {
  pushd ${BUILD_DIR}/${TIMESTAMP}/daos
  scons MPI_PKG=any \
        --build-deps=${SCONS_BUILD_DEPS} \
        --config=force \
        BUILD_TYPE=${DAOS_BUILD_TYPE} \
        install ${SCONS_EXTRA_ARGS}
  popd
}


# Clone and checkout IOR and MDTest
function clone_ior_mdtest() {
  pushd ${BUILD_DIR}/${TIMESTAMP}
  git clone https://github.com/hpc/ior.git
  pushd ${BUILD_DIR}/${TIMESTAMP}/ior
  if [ ! -z "${IOR_COMMIT}" ]; then
      git checkout -b "${IOR_COMMIT}" "${IOR_COMMIT}"
  fi

  # Apply patch to make all processes write the same data.
  # This is needed to reduce pool space usage so a larger number of clients can be used.
  cp ${CURRENT_DIR}/patches/ior_dedup_workaround.patch .
  git apply ior_dedup_workaround.patch

  print_repo_info |& tee -a ${BUILD_DIR}/${TIMESTAMP}/repo_info.txt
  ./bootstrap
  popd
  popd
}

# Build IOR and MDTest
function build_ior_mdtest() {
  pushd ${BUILD_DIR}/${TIMESTAMP}/ior
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
}

# Perform a basic revision of the built binaries
function check_target_files_exist() {
  declare -a PRECIOUS_FILES=("bin/daos"
                             "bin/daos_server"
                             "bin/daos_agent"
                             "bin/dmg"
                             "ior${MPI_SUFFIX}/bin/${IOR_BIN}"
                             "ior${MPI_SUFFIX}/bin/${MDTEST_BIN}"
                             )
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
  local path=${1}
  if ! ldd ${path} | grep -q libdaos.so ; then
    echo "Error: file ${path} does not link DAOS libraries"
    exit 1
  fi
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

function main() {
  trap 'check_retcode $? ${BASH_COMMAND}' EXIT
  set -e
  set -o pipefail

  setup_env
  install_python_deps
  setup_build_dir
  clone_daos
  build_daos
  clone_ior_mdtest
  build_ior_mdtest

  check_target_files_exist
  check_daos_linkage ${LATEST_DAOS}/ior${MPI_SUFFIX}/bin/${IOR_BIN}
  check_daos_linkage ${LATEST_DAOS}/ior${MPI_SUFFIX}/bin/${MDTEST_BIN}
}

main


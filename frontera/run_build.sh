#!/bin/bash
#
# Build DAOS locally.
#

# Default params
BUILD_DIR="${WORK}/BUILDS/master"
TIMESTAMP=$(date +%Y%m%d)
DAOS_BRANCH="master"
DAOS_COMMIT=""
EXTRA_DAOS_BRANCHES=()
EXTRA_DAOS_CHERRY=()
# temporarily needed for 2.4
#EXTRA_DAOS_CHERRY=(527b38a8c8a2890e8741543fda12638cc130d0ac)
DAOS_BUILD_TYPE="release"
MPI_TARGET="mvapich2"
IOR_COMMIT=""
SCONS_BUILD_DEPS="yes"
SCONS_EXTRA_ARGS=""
SYSTEM_NAME=""
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
      echo ""
      echo "  --system=${SYSTEM_NAME}"
      echo "    System name running build process"
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
    --system*) if [[ "$1" != *=* ]]; then shift; fi
      SYSTEM_NAME="${1#*=}";;
    *)
      >&2 printf "Invalid argument: $1\n"
      exit 1
      ;;
  esac
  shift
done

# Auto-detect running in a slurm job and use multiple processes to build
if [ -z $SCONS_EXTRA_ARGS ] && [ ! -z $SLURM_JOB_NUM_NODES  ]; then
    build_cores=$(scontrol show node $(hostname | cut -d "." -f 1) | grep -o "CPUAlloc=[0-9]\+" | grep -o "[0-9]\+")
    build_cores=$(( $build_cores - 4 ))
    SCONS_EXTRA_ARGS="-j$build_cores"
    echo "Detecting running in slurm. Building with ${SCONS_EXTRA_ARGS}"
fi

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LATEST_DAOS=${BUILD_DIR}/${TIMESTAMP}/daos/install

# Get the system name
function get_system_name() {

  # Auto-detect system name if not provided
  if [ -z "$SYSTEM_NAME" ]; then
    local host=$(hostname)

    if [[ $host == "ebuild"* ]] || [[ $host == "edaos"* ]]; then
            SYSTEM_NAME="endeavour"
    elif [[ $host == *"frontera"* ]]; then
            SYSTEM_NAME="frontera"
    fi

  else
    SYSTEM_NAME=$(echo "$SYSTEM_NAME" | tr '[:upper:]' '[:lower:]' )
  fi

  if [ ! "$SYSTEM_NAME" == "endeavour" ] && [ ! "$SYSTEM_NAME" == "frontera" ]; then
    echo "Endeavour or Frontera are the only supported systems"
    return 1
  fi

}

# Setup the environment
function setup_env() {
  export PATH=~/.local/bin:$PATH
  export PATH="${WORK}/daos_deps/bin:$PATH"
  export LD_LIBRARY_PATH="${WORK}/daos_deps/lib:$LD_LIBRARY_PATH"
  export LIBRARY_PATH="${WORK}/daos_deps/lib:$LIBRARY_PATH"
  export CPATH="${WORK}/daos_deps/include:$CPATH"
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
  if [ $(git_has_commit "527b38a") = true ]; then
    hack_branch="origin/dbohning/io500-base-527b38a"
  elif [ $(git_has_commit "cc7c11c") = true ]; then
     hack_branch="origin/dbohning/io500-base-cc7c11c"
  elif [ $(git_has_commit "e64dd3b") = true ]; then
    hack_branch="origin/dbohning/io500-base-e64dd3b"
  elif [ $(git_has_commit "ec18c59") = true ]; then
    hack_branch="origin/dbohning/io500-base-ec18c59"
  elif [ $(git_has_commit "e2a10d7") = true ]; then
    hack_branch="origin/dbohning/io500-base-e2a10d7"
  elif [ $(git_has_commit "1185938") = true ]; then
    hack_branch="origin/dbohning/io500-base-1185938"
  elif [ $(git_has_commit "5c330f9") = true ]; then
    hack_branch="origin/dbohning/io500-base-5c330f9"
  else
    echo "Failed to determine hack branch!"
    exit 1
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

function git_cherry_pick() {
    local commit="$1"
    echo "Cherry-picking commit: ${commit}"
    git log -n 1 --pretty=format:"commit %H%n" "${commit}" || return
    git cherry-pick --no-edit ${commit} || return
    echo ""
}
git_cherry_pick_cond() {
    local commit="$1"

    if [ ! $(git_has_commit "$1") = true ]; then
        git_cherry_pick "$1"
    fi
}

function cherry_pick_daos_commits() {
    for COMMIT in "${EXTRA_DAOS_CHERRY[@]}"
    do
        git_cherry_pick "${COMMIT}"
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

function install_daos_deps() {
    local rc=0
    "${CURRENT_DIR}/utils/check_for_lib" "lmdb"
    rc=$?
    if [ $rc -ne 0 ]; then
        "${CURRENT_DIR}/utils/build_install_lmdb" "${WORK}/daos_deps" || return
        "${CURRENT_DIR}/utils/check_for_lib" "lmdb" || return
    fi
    "${CURRENT_DIR}/utils/check_for_lib" "capstone"
    rc=$?
    if [ $rc -ne 0 ]; then
        "${CURRENT_DIR}/utils/build_install_capstone" "${WORK}/daos_deps" || return
        "${CURRENT_DIR}/utils/check_for_lib" "capstone" || return
    fi
}

# Setup a new build directory, removing if it already exists
function setup_build_dir() {
    rm -rf ${BUILD_DIR}/${TIMESTAMP}
    mkdir -p ${BUILD_DIR}/${TIMESTAMP}
    rm -f ${BUILD_DIR}/latest
    ln -s ${BUILD_DIR}/${TIMESTAMP} ${BUILD_DIR}/latest
}

# Copy a patch from the script directory and apply it
function copy_and_apply_patch() {
    local patch="$1"
    local patch_path="${CURRENT_DIR}/patches/$patch"
    cp "$patch_path" .
    echo "Applying patch $patch"
    git apply "$patch_path"
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

    # Point to removed mercury patch for old builds
    local config="${BUILD_DIR}/${TIMESTAMP}/daos/utils/build.config"
    sed -i \
        's/https:\/\/raw.githubusercontent.com\/daos-stack\/mercury\/master\/na_ucx_changes.patch/https:\/\/raw.githubusercontent.com\/daos-stack\/mercury\/d993cda60d9346d1bd3451f334340d3b08e5aa42\/na_ucx_changes.patch/' \
        "$config"

    # SCONS_ENV option
    if [ $(git_has_commit "0f55c8157ef30d2d44573502d40fe6dab3486f27") = true ]; then
        git_cherry_pick_cond "32aaa88543ec721471b5902364ac668ac67b4bc9" |& tee -a ${BUILD_DIR}/${TIMESTAMP}/repo_info.txt
    else
        copy_and_apply_patch amd_scons_env.patch.df1f8034e516b5887a37ae4733d39cbd669612ea |& tee -a ${BUILD_DIR}/${TIMESTAMP}/repo_info.txt
    fi

    # Patch for os.environ.copy()
    if [ $(git_has_commit "efe7889c02e2a0781c3661a652785404bcdc25a2") = true ]; then
        git_cherry_pick_cond "de10c18c46ac054b2ada4e4b2a7245988e78cd2b" |& tee -a ${BUILD_DIR}/${TIMESTAMP}/repo_info.txt
    fi

    # Build flags fixes
    if [ $(git_has_commit "f135357ac070a38cb574f8404f9cbf7a7822f791") = true ]; then
        copy_and_apply_patch daos_scons_linkage.patch.f135357ac070a38cb574f8404f9cbf7a7822f791
    elif [ $(git_has_commit "99e41bc1b70e7431cdda907479e2bccdaaac48f6") = true ]; then
        copy_and_apply_patch daos_scons_linkage.patch.99e41bc1b70e7431cdda907479e2bccdaaac48f6
    elif [ $(git_has_commit "db6ac13c819d8053e5a94541be2d6df0fcd11a2b") = true ]; then
        copy_and_apply_patch daos_scons_linkage.patch.db6ac13c819d8053e5a94541be2d6df0fcd11a2b
    elif [ $(git_has_commit "e7abecef825d4dead9fb05bc061fa257d6c98767") = true ]; then
        copy_and_apply_patch daos_scons_linkage.patch.e7abecef825d4dead9fb05bc061fa257d6c98767
    elif [ $(git_has_commit "6a3c9910ea2a7b647f818bed9754bb3363b78770") = true ]; then
        copy_and_apply_patch daos_scons_linkage.patch.6a3c9910ea2a7b647f818bed9754bb3363b78770
    else
        copy_and_apply_patch daos_scons_linkage.patch |& tee -a ${BUILD_DIR}/${TIMESTAMP}/repo_info.txt
    fi

    # libfuse build fixes
    if [ $(git_has_commit "0268945f7aa8adf3f83d87a1d73519f614d6c3a4") = true ]; then
        git_cherry_pick_cond "e2e49e42fbdc085ace2c277dd73ef2eb21d0161e" |& tee -a ${BUILD_DIR}/${TIMESTAMP}/repo_info.txt
        # Not clear whether this one is related, but the problem was introduced around the same time
        git_cherry_pick_cond "0bb652d838c8030ae1d57f55b6be08ceaa5da59c" |& tee -a ${BUILD_DIR}/${TIMESTAMP}/repo_info.txt
    fi

    # pil4dfs strncmp fix
    if [ $(git_has_commit "912c9a4c776e7755e4b2d3530dd29fcd30eb4d39") = true ]; then
        # This commit will need to be updated after https://github.com/daos-stack/daos/pull/14041 is merged
        git_cherry_pick_cond "4224f58a49ee83d96731b2ae2edd51a583608425" |& tee -a ${BUILD_DIR}/${TIMESTAMP}/repo_info.txt
    fi

    scons MPI_PKG=any \
          --build-deps=${SCONS_BUILD_DEPS} \
          --config=force \
          BUILD_TYPE=${DAOS_BUILD_TYPE} \
          SCONS_ENV=full \
          COMPILER=gcc \
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
    copy_and_apply_patch ior_dedup_workaround.patch

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
                --with-cuda=no \
                --with-gpuDirect=no \
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
  #trap 'check_retcode $? ${BASH_COMMAND}' EXIT
  set -e
  set -o pipefail

  get_system_name || exit
  setup_env || exit
  install_python_deps || exit
  install_daos_deps || exit

  # Capture all bad returns
  trap 'check_retcode $? ${BASH_COMMAND}' EXIT

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


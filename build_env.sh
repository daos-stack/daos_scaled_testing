#!/bin/sh

MPI_TARGET=${1}

export IOR_BIN=daosior
export MDTEST_BIN=daosmdt

# Activate mpi

function activate_mpi(){
  NAME=${1}
  MPI_DIR=${2}

  export PATH=${MPI_DIR}/bin:${PATH}
  export LD_LIBRARY_PATH=${MPI_DIR}/lib:${LD_LIBRARY_PATH}
  export PKG_CONFIG_PATH=${MPI_DIR}/lib/pkgconfig:${PKG_CONFIG_PATH}
  export MPI_BIN=${MPI_DIR}/bin
  export MPI_INCLUDE=${MPI_DIR}/include
  export MPI_LIB=${MPI_DIR}/lib
  export MPI_COMPILER=${NAME}
  export MPI_SUFFIX=_${NAME}
  export MPI_HOME=${MPI_DIR}
}

if [ -z "${MPI_TARGET}" ]; then
  MPI_TARGET=mvapich2
  echo "Using default option: ${MPI_TARGET}"
fi

case ${MPI_TARGET} in
  mvapich2)
    module unload intel
    module load gcc/9.1.0
    module load mvapich2-x/2.3
    export MPI_SUFFIX=_${MPI_TARGET}
    export MPI_BIN=$(dirname $(which mpicc))
    VER=`mpichversion | grep "MVAPICH2 Version:" | cut -d ":" -f 2 | sed -e 's/^[[:space:]]*//'`
    echo "MVAPICH2 Version: ${VER}"
    ;;
  openmpi)
    activate_mpi ${MPI_TARGET} ${OPENMPI_DIR}
    VER=`ompi_info | grep "Open MPI:" | cut -d ":" -f 2 | sed -e 's/^[[:space:]]*//'`
    echo "Open MPI Version: ${VER}"
    ;;
  mpich)
    activate_mpi ${MPI_TARGET} ${MPICH_DIR}
    VER=`mpichversion | grep "MPICH Version:" | cut -d ":" -f 2 | sed -e 's/^[[:space:]]*//'`
    echo "MPICH Version: ${VER}"
    ;;
  *)
    echo "Error unknown target \"${MPI_TARGET}\": mvapich2, openmpi, or mpich"
esac

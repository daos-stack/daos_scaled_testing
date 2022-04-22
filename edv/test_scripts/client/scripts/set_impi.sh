. /opt/intel/impi/2021.2.0.215/setvars.sh --force
export PYTHONPATH=/panfs/users/${USER}/apps/MPI/resnet/install:$PYTHONPATH
export I_MPI_LIBRARY_KIND=release_mt
export I_MPI_OFI_LIBRARY_INTERNAL=0
export I_MPI_OFI_PROVIDER="verbs;ofi_rxm"
export FI_UNIVERSE_SIZE=2048
export CCL_CONFIGURATION=cpu_icc
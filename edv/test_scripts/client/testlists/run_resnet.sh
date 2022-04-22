#!/bin/sh

. /opt/intel/impi/2021.2.0.215/setvars.sh --force
export PYTHONPATH=/nfs/scratch04/schan15/resnet50:$PYTHONPATH
export LD_LIBRARY_PATH=/panfs/users/schan15/SC21/setup/level-zero/lib64:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/panfs/users/schan15/SC21/setup/level-zero/install/lib64:$LD_LIBRARY_PATH
export I_MPI_LIBRARY_KIND=release_mt
export I_MPI_OFI_LIBRARY_INTERNAL=0
export I_MPI_OFI_PROVIDER="verbs;ofi_rxm"
export FI_UNIVERSE_SIZE=2048
export CCL_CONFIGURATION=cpu_icc
export TB=daos_rel201rc1
source /panfs/users/schan15/client/scripts/client_env.sh

date | tee /tmp/resnet50_16p_1ppn.log

#echo "mpirun -np 16 -ppn 1 -hosts edaosc057,edaosc058,edaosc059,edaosc060,edaosc061,edaosc062,edaosc063,edaosc064,edaosc065,edaosc066,edaosc067,edaosc068,edaosc069,edaosc070,edaosc071,edaosc072  python3 /panfs/users/schan15/SC21/setup/pytorch_imagenet_resnet50.py --train-dir /tmp/daos/ilsvrc12_raw/train/ --val-dir /tmp/daos/ilsvrc12_raw/val/ --no-cuda --epochs 1 2>&1" | tee -a /tmp/resnet50_16p_1ppn.log

#mpirun -np 16 -ppn 1 -hosts edaosc057,edaosc058,edaosc059,edaosc060,edaosc061,edaosc062,edaosc063,edaosc064,edaosc065,edaosc066,edaosc067,edaosc068,edaosc069,edaosc070,edaosc071,edaosc072  python3 /panfs/users/schan15/SC21/setup/pytorch_imagenet_resnet50.py --train-dir /tmp/daos/ilsvrc12_raw/train/ --val-dir /tmp/daos/ilsvrc12_raw/val/ --no-cuda --epochs 1 2>&1 | tee -a /tmp/resnet50_16p_1ppn.log

#mpirun -np 1 python3 /panfs/users/schan15/SC21/setup/pytorch_imagenet_resnet50.py --train-dir /tmp/daos/ilsvrc12_raw/train/ --val-dir /tmp/daos/ilsvrc12_raw/val/ --no-cuda --epochs 1 2>&1 | tee -a /tmp/resnet50_16p_1ppn.log

date | tee -a /tmp/resnet50_16p_1ppn.log


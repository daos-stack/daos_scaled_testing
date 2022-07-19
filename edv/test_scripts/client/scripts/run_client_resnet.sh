#!/bin/sh

ps -ef | grep ${USER}

echo START time
date

export I_MPI_OFI_LIBRARY_INTERNAL=0
export I_MPI_OFI_PROVIDER="verbs;ofi_rxm"
export I_MPI_DEBUG=4

export SRV_HOSTLIST="${RUNDIR}/../server/hostlists/srv_hostlist${NSERVER}"
export CLI_HOSTLIST="${RUNDIR}/hostlists/cli_hostlist${NCLIENT}"
export envIL=""
export NPROCESS=$(( $NCLIENT * $PPN ))
export PLABEL="p_${TESTDIR}"
export CLABEL="c_${TESTDIR}"

#export EXTRA_ENV="-genv DARSHAN_LOGPATH ${RESULTDIR}/darshanlog -genv LD_PRELOAD /panfs/users/rpadma2/apps/darshan-install-impi/lib/libdarshan.so"
export EXTRA_ENV=""

mkdir -p ${RESULTDIR}/darshanlog

echo NPROCESS=${NPROCESS}

echo "Starting servers"
clush --user=daos_server -w ${SRV_HEADNODE} "export TB=${TB}; export LUSER=${USER}; export NSERVER=${NSERVER}; cd ${RUNDIR}/../server; ./run_server.sh" 2>&1 &

sleep 600

clush -S --user=daos_server --hostfile=${SRV_HOSTLIST} "grep 'started on rank' /tmp/daos_control.log" 2>&1

if [[ $? -ne 0 ]]; then
  echo Server failed to start
  killall clush
  clush --user=daos_server --hostfile=${SRV_HOSTLIST} "pkill -9 daos; pkill -9 daos"
  ps -ef | grep TB= | grep ssh | kill -9 `awk '{print $2}'`
  exit 1
fi

ls -al /panfs/users/rpadma2/apps/${MPI}/lammps

echo "Sourcing env"
if [[ "$TEST" =~ "EFISPEC" ]]; then
  . /opt/intel/oneAPI/latest/setvars.sh
fi

if [[ "$MPI" =~ "IMPI" ]]; then
  . /opt/intel/impi/2021.2.0.215/setvars.sh --force
else
  export LD_LIBRARY_PATH=${MPIPATH}/lib:$LD_LIBRARY_PATH
  export PATH=${MPIPATH}/bin:$PATH
fi

. ${RUNDIR}/scripts/client_env.sh

echo "Unmounting"
${RUNDIR}/scripts/unmount.sh
echo

rm ${RESULTDIR}/daos_server.attach_info_tmp
echo "Number of Client nodes"
cat ${CLI_HOSTLIST} | wc -l
echo

echo
echo Running $TB
which daos_agent
echo

echo "Cleaning Agent"
clush --hostfile=${CLI_HOSTLIST} "export TB=$TB; export RUNDIR=${RUNDIR}; cd ${RUNDIR}/scripts; source client_env.sh; ./clean_agent.sh"
sleep 5
echo

echo "Starting Agent"
clush --hostfile=${CLI_HOSTLIST} "export TB=$TB; export RUNDIR=${RUNDIR}; cd ${RUNDIR}/scripts; source client_env.sh; ./start_agent.sh" &
sleep 5
echo

echo "Dumping attach info"
daos_agent -i -o ${RUNDIR}/scripts/daos_agent-${USER}.yml dump-attachinfo -o  ${RESULTDIR}/daos_server.attach_info_tmp
cat ${RESULTDIR}/daos_server.attach_info_tmp
echo

echo "Creating Pool"
CMD="dmg -o ${RUNDIR}/scripts/daos_control.yml pool create -s ${SCM} -n ${NVME} -p ${PLABEL} -r=${RANKS}"
echo ${CMD}
OUT="$(eval ${CMD})"
RC=$?
if [[ ${RC} -ne 0 ]]; then
  echo Pool create failed
  killall daos_agent
  killall clush
  clush --user=daos_server --hostfile=${SRV_HOSTLIST} "pkill -9 daos; pkill -9 daos"
  ps -ef | grep TB= | grep ssh | kill -9 `awk '{print $2}'`
  exit 1
fi
echo ${OUT}
POOL=$(echo ${OUT} | grep "UUID" | cut -d ':' -f 3 | sed 's/^[ \t]*//;s/[ \t]*$//' | awk '{print $1}')
echo POOL is ${POOL}
export POOL=${POOL}
dmg -o ${RUNDIR}/scripts/daos_control.yml pool query ${PLABEL}
echo

echo "Creating Container"
CMD="daos cont create --pool=${PLABEL} --label=${CLABEL} --type POSIX --properties=rf:${RF} --sys-name=daos_server"
echo ${CMD}
OUT="$(eval ${CMD})"
RC=$?
if [[ ${RC} != 0 ]]; then
  echo Container create failed
  killall daos_agent
  killall clush
  clush --user=daos_server --hostfile=${SRV_HOSTLIST} "pkill -9 daos; pkill -9 daos"
  ps -ef | grep TB= | grep ssh | kill -9 `awk '{print $2}'`
  exit 1
fi
echo ${OUT}
echo

daos cont get-prop --pool=${PLABEL} --cont=${CLABEL}

clush -S --hostfile=${CLI_HOSTLIST} "rm -rf ${MOUNTDIR}; mkdir -p ${MOUNTDIR}"

if [[ $? -ne 0 ]]; then
  echo Failed to create ${MOUNTDIR}
  killall daos_agent
  killall clush
  clush --user=daos_server --hostfile=${SRV_HOSTLIST} "pkill -9 daos; pkill -9 daos"
  ps -ef | grep TB= | grep ssh | kill -9 `awk '{print $2}'`
  exit 1
fi

if [ "$MOUNT_DFUSE" == "1" ]; then
  echo "Mounting Dfuse"
  clush --hostfile=${CLI_HOSTLIST} "export TB=${TB}; export RUNDIR=${RUNDIR}; export PLABEL=${PLABEL}; export CLABEL=${CLABEL}; export MOUNTDIR=${MOUNTDIR}; export DFUSECACHE=${DFUSECACHE}; ${RUNDIR}/scripts/mount_dfuse.sh"

  if [[ ! -d ${MOUNTDIR} ]]; then
    echo Dfuse mount unsuccessful!!
    killall daos_agent
    killall clush
    clush --user=daos_server --hostfile=${SRV_HOSTLIST} "pkill -9 daos; pkill -9 daos"
    ps -ef | grep TB= | grep ssh | kill -9 `awk '{print $2}'`
    exit 1
  fi

  echo
  clush --hostfile=${CLI_HOSTLIST} "mount | grep dfuse"
  echo
fi

if [[ "$IL" == "1" ]]; then
  #export envIL="-env LD_PRELOAD=${BUILDDIR}/${TB}/CLIENT/install/lib64/libioil.so -env D_IL_REPORT=5 -env D_LOG_MASK=ERR"
  export envIL="-env LD_PRELOAD=${BUILDDIR}/${TB}/CLIENT/install/lib64/libioil.so -env D_LOG_MASK=ERR"
fi

export LOCALHOST=$(hostname)

. /opt/intel/impi/2021.2.0.215/setvars.sh --force
export PYTHONPATH=/panfs/users/${USER}/apps/MPI/resnet/install:$PYTHONPATH
export I_MPI_LIBRARY_KIND=release_mt
export I_MPI_OFI_LIBRARY_INTERNAL=0
export I_MPI_OFI_PROVIDER="verbs;ofi_rxm"
export FI_UNIVERSE_SIZE=2048
export CCL_CONFIGURATION=cpu_icc
. ${RUNDIR}/scripts/client_env.sh

echo "Copy DataSet to DAOS mountpoint"
#clush -w ${LOCAL_HOST} "cd ${RUNDIR}/scripts; source set_impi.sh; mpirun -np 16 /panfs/users/schan15/SC21/setup/mfu/install/bin/dcp /panfs/projects/ML_datasets/imagenet/ilsvrc12_raw daos://${PLABEL}/${CLABEL}"
echo "mpirun ${envIL} -np 16 -ppn 1 -hosts edaosc057,edaosc058,edaosc059,edaosc060,edaosc061,edaosc062,edaosc063,edaosc064,edaosc065,edaosc066,edaosc067,edaosc068,edaosc069,edaosc070,edaosc071,edaosc072 /panfs/users/rpadma2/apps/MPI/mpifileutils/install/bin/dcp /panfs/projects/ML_datasets/imagenet/ilsvrc12_raw daos://${PLABEL}/${CLABEL}"
#mpirun ${envIL} -np 16 -ppn 1 -hosts edaosc057,edaosc058,edaosc059,edaosc060,edaosc061,edaosc062,edaosc063,edaosc064,edaosc065,edaosc066,edaosc067,edaosc068,edaosc069,edaosc070,edaosc071,edaosc072 /panfs/users/rpadma2/apps/MPI/mpifileutils/install/bin/dcp /panfs/projects/ML_datasets/imagenet/ilsvrc12_raw daos://${PLABEL}/${CLABEL}

echo "Running pytorch benchmark"
#clush -w ${LOCAL_HOST} "cd ${RUNDIR}/scripts; source set_impi.sh; mpirun -np 2 python3 /panfs/users/${USER}/apps/MPI/resnet/install/pytorch_imagenet_resnet50.py --train-dir ${MOUNTDIR}/ilsvrc12_raw/train/ --val-dir ${MOUNTDIR}/ilsvrc12_raw/val/ --no-cuda --epochs 1"
#echo "mpirun ${envIL} -np 2 python3 /panfs/users/${USER}/apps/MPI/resnet/install/pytorch_imagenet_resnet50.py --train-dir ${MOUNTDIR}/ilsvrc12_raw/train/ --val-dir ${MOUNTDIR}/ilsvrc12_raw/val/ --no-cuda --epochs 1"
#mpirun ${envIL} -np 2 python3 /panfs/users/${USER}/apps/MPI/resnet/install/pytorch_imagenet_resnet50.py --train-dir ${MOUNTDIR}/ilsvrc12_raw/train/ --val-dir ${MOUNTDIR}/ilsvrc12_raw/val/ --no-cuda --epochs 1
echo "mpirun ${envIL} -np 16 -ppn 1 -hosts edaosc057,edaosc058,edaosc059,edaosc060,edaosc061,edaosc062,edaosc063,edaosc064,edaosc065,edaosc066,edaosc067,edaosc068,edaosc069,edaosc070,edaosc071,edaosc072 python3 /panfs/users/${USER}/apps/MPI/resnet/install/pytorch_imagenet_resnet50.py --train-dir ${MOUNTDIR}/ilsvrc12_raw/train/ --val-dir ${MOUNTDIR}/ilsvrc12_raw/val/ --no-cuda --epochs 1"
mpirun ${envIL} -np 16 -ppn 1 -hosts edaosc057,edaosc058,edaosc059,edaosc060,edaosc061,edaosc062,edaosc063,edaosc064,edaosc065,edaosc066,edaosc067,edaosc068,edaosc069,edaosc070,edaosc071,edaosc072 python3 /panfs/users/${USER}/apps/MPI/resnet/install/pytorch_imagenet_resnet50.py --train-dir ${MOUNTDIR}/ilsvrc12_raw/train/ --val-dir ${MOUNTDIR}/ilsvrc12_raw/val/ --no-cuda --epochs 1 2>&1 |  tee ${RESULTDIR}/resnet50_out.log

read -p "Press any key"
echo Pool query after ${TEST}
dmg -o ${RUNDIR}/scripts/daos_control.yml pool query $PLABEL

#echo "Destroying Container"
#x="true"
#echo "Press any key to continue"
#while [ $x == "true" ] ; do
#	read -t 3 -n 1
#	if [ $? = 0 ] ; then
#		echo "Exiting"
#		x="false"
#	fi
#done

echo
echo "Copying clientlogs"
echo

rm -rf ${RESULTDIR}/clientlogs
mkdir -p ${RESULTDIR}/clientlogs

clush --hostfile=${CLI_HOSTLIST} "mkdir -p ${RESULTDIR}/clientlogs/\`hostname\`; cp /tmp/daos_agent-${USER}/daos_client.log ${RESULTDIR}/clientlogs/\`hostname\`/"

echo
echo "Copying serverlogs"
echo

rm -rf ${RESULTDIR}/serverlogs
mkdir -p ${RESULTDIR}/serverlogs
chmod 777 ${RESULTDIR}/serverlogs

clush --user=daos_server --hostfile=${SRV_HOSTLIST} "export TB=${TB}; cd ${RUNDIR}/../server; source srv_env.sh; daos_metrics -S 0 --csv > /tmp/daos_metrics_0.csv; daos_metrics -S 1 --csv > /tmp/daos_metrics_1.csv; dmesg > /tmp/daos_dmesg.txt"

clush --user=daos_server --hostfile=${SRV_HOSTLIST} "mkdir -p ${RESULTDIR}/serverlogs/\`hostname\`; cp /tmp/daos_*.* ${RESULTDIR}/serverlogs/\`hostname\`/; chmod -R 777 ${RESULTDIR}/serverlogs/\`hostname\`/"

echo Files after run
date
ls ${MOUNTDIR} | wc -l
date
echo
echo
echo Disk usage after run
date
#du -sh ${MOUNTDIR}
date
echo
echo

cd ${RUNDIR}

echo Deleting files
date
#timeout -k 10 900 rm -rf ${MOUNTDIR}/ilsvrc12_raw
echo Done
date
echo

#echo Files after delete
#date
#ls ${OUTDIR} | wc -l
#date

echo Unmounting
${RUNDIR}/scripts/unmount.sh

#echo "Destroying Container"
#CMD="daos cont destroy ${PLABEL} ${CLABEL}"
#echo ${CMD}
#OUT="$(eval ${CMD})"
#RC=$?
#if [[ ${RC} -ne 0 ]]; then
#  echo Container destroy failed
#  killall daos_agent
#  killall clush
#  exit 1
#fi
#echo ${OUT}

echo "Destroying Pool"
CMD="dmg -o ${RUNDIR}/scripts/daos_control.yml pool destroy ${PLABEL}"
echo ${CMD}
OUT="$(eval ${CMD})"
RC=$?
if [[ ${RC} -ne 0 ]]; then
  echo Pool destroy failed
  killall daos_agent
  killall clush
  clush --user=daos_server --hostfile=${SRV_HOSTLIST} "pkill -9 daos; pkill -9 daos"
  ps -ef | grep TB= | grep ssh | kill -9 `awk '{print $2}'`
  exit 1
fi
echo ${OUT}

killall daos_agent
killall clush
clush --user=daos_server --hostfile=${SRV_HOSTLIST} "pkill -9 daos; pkill -9 daos"
ps -ef | grep TB= | grep ssh | kill -9 `awk '{print $2}'`

echo END time
date

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
clush --user=daos_server -w ${SRV_HEADNODE} "export TB=${TB}; export NSERVER=${NSERVER}; cd ${RUNDIR}/../server; ./run_server.sh" 2>&1 &

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

#LFS
#mkdir -p ${MOUNTDIR}/vpic
#if [[ -d "${MOUNTDIR}/vpic" ]]; then
#  echo "${MOUNTDIR}/vpic" exists
#fi

if [[ "$IL" == "1" ]]; then
  #export envIL="-env DARSHAN_LOGPATH=${RESULTDIR}/darshanlog -env LD_PRELOAD=/panfs/users/rpadma2/apps/darshan-install-impi/lib/libdarshan.so:${BUILDDIR}/${TB}/CLIENT/install/lib64/libioil.so -env D_IL_REPORT=5 -env D_LOG_MASK=ERR"
  #export envIL="-env LD_PRELOAD=${BUILDDIR}/${TB}/CLIENT/install/lib64/libioil.so -env D_IL_REPORT=5 -env D_LOG_MASK=ERR"
  export envIL="-env LD_PRELOAD=${BUILDDIR}/${TB}/CLIENT/install/lib64/libioil.so -env D_LOG_MASK=ERR"
fi

echo

if [[ "${TEST}" =~ "IOR" ]]; then
  #export IORWRITECMD="${RUNDIR}/../apps/ior/install/bin/ior -a DFS -b 150G -C -e -w -W -g -G 27 -k -i 1 -s 1 -o /testFile -O stoneWallingWearOut=1 -O stoneWallingStatusFile=${SWFILEWRITE} -D 60 -d 5 -t 1M --dfs.cont ${CONT} --dfs.group daos_server --dfs.pool ${POOL} --dfs.oclass SX --dfs.chunk_size 1M -v"

  #export IORREADCMD="${RUNDIR}/../apps/ior/install/bin/ior -a DFS -b 150G -C -Q 1 -e -r -R -g -G 27 -k -i 1 -s 1 -o /testFile -O stoneWallingWearOut=1 -O stoneWallingStatusFile=${SWFILEREAD} -D 60 -d 5 -t 1M --dfs.cont ${CONT} --dfs.group daos_server --dfs.pool ${POOL} --dfs.oclass SX --dfs.chunk_size 1M -v"

  export IORREADCMD="${RUNDIR}/../apps/ior/install/bin/ior -a DFS -w -r -o /testFile -t 1m -b 150m -i 1 --dfs.cont ${CONT} --dfs.group daos_server --dfs.pool ${POOL}"

  export TESTCMD=${IORREADCMD}
else
  if [[ "$TEST" =~ "EFISPEC" ]]; then
    cp -r ${APPSRC} ${MOUNTDIR}
    cp -f ${APPINFILE} ${APPINFILEDEST}/e2vp2.cfg
    cat ${APPINFILEDEST}/e2vp2.cfg
  fi

  if [[ "$TEST" =~ "LAMMPS" ]]; then
    ls -al ${APPSRC}
  fi

  if [[ ! -z "${APPINFILE}" ]]; then
    cat ${APPINFILE}
  fi
  mkdir -p ${OUTDIR}

  cd ${APPRUNDIR}
fi

echo
echo

echo Files before run
ls ${OUTDIR} | wc -l
echo Disk usage before run
du -sh ${OUTDIR}
echo

echo "RUNNING:"
date
echo
#I_MPI_DEBUG=4 mpirun -n ${NPROCESS} --hostfile ${CLI_HOSTLIST} -ppn ${PPN} -genv I_MPI_PIN_PROCESSOR_LIST=0-7 ${TESTCMD}

#export DARSHAN_LOGPATH="${RESULTDIR}/darshanlog"
#export LD_PRELOAD="/panfs/users/rpadma2/apps/darshan-install-impi/lib/libdarshan.so"

echo "which mpiexec"
which mpiexec
echo

echo ROMIO_FSTYPE_FORCE=${ROMIO_FSTYPE_FORCE}
echo "mpiexec -bootstrap ssh ${EXTRA_ENV} ${envIL} -n ${NPROCESS} --hostfile ${CLI_HOSTLIST} -ppn ${PPN} ${TESTCMD}"
echo
mpiexec -bootstrap ssh ${EXTRA_ENV} ${envIL} -n ${NPROCESS} --hostfile ${CLI_HOSTLIST} -ppn ${PPN} ${TESTCMD}
echo

echo Pool query after ${TEST}
dmg -o ${RUNDIR}/scripts/daos_control.yml pool query $PLABEL

echo 

if [[ "${TEST}" =~ "IOR" ]]; then
  ${RUNDIR}/scripts/mount_dfuse.sh
  if [[ ! -d ${MOUNTDIR} ]]; then
    echo Dfuse mount unsuccessful!!
    killall daos_agent
    killall clush
    clush --user=daos_server --hostfile=${SRV_HOSTLIST} "pkill -9 daos; pkill -9 daos"
    ps -ef | grep TB= | grep ssh | kill -9 `awk '{print $2}'`
    exit 1
  else
    ls -al ${MOUNTDIR}
  fi
fi

if [[ "${TEST}" =~ "EFISPEC" ]]; then
  cp e2vp2.lst ${RESULTDIR}
fi

echo
echo Test Complete
date
echo

# Copy DAOS client and server logs
echo "Copying logs"
${RUNDIR}/scripts/collect_logs.sh
echo

echo Files after run
date
ls ${OUTDIR} | wc -l
date
echo
echo
echo Disk usage after run
date
du -sh ${OUTDIR}
date
echo
echo

cd ${RUNDIR}

echo Deleting files
date
timeout -k 10 900 rm -rf ${OUTDIR}
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

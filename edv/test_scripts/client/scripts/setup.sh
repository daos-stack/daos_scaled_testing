#!/bin/sh

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
clush --hostfile=${CLI_HOSTLIST} "export TB=$TB; export RUNDIR=${RUNDIR}; cd ${RUNDIR}/scripts; source client_env.sh; ./clean_agent.sh" &
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
echo POOL CREATE RC is ${RC}
if [[ ${RC} ]]; then
  echo Pool create failed
  exit 1
fi
POOL=`cat ${OUT} | grep "UUID" |  awk '{print $3}'`
echo ${POOL}
export POOL=${POOL}
dmg -o ${RUNDIR}/scripts/daos_control.yml pool query ${PLABEL}
echo

echo "Creating Container"
CMD="daos cont create --pool=${PLABEL} --type POSIX --properties=rf:${RF} --sys-name=daos_server"
echo ${CMD}
CONT=`${CMD} | grep "UUID" | awk '{print $4}'`
export CONT=$CONT
echo $CONT
echo

daos cont get-prop --cont=${CONT} --pool=${PLABEL}

clush --hostfile=${CLI_HOSTLIST} "rm -rf /tmp/daos_m/${USER}; mkdir -p /tmp/daos_m/${USER}"

if [ "$MOUNT_DFUSE" == "1" ]; then
  echo "Mounting Dfuse"
  clush --hostfile=${CLI_HOSTLIST} "export TB=$TB; export RUNDIR=${RUNDIR}; export PLABEL=$PLABEL; export CONT=$CONT; ${RUNDIR}/scripts/mount_dfuse.sh"
  echo
fi


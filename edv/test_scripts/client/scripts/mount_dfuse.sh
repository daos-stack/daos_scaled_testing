#!/bin/sh

source  ${RUNDIR}/scripts/client_env.sh

#taskset -c 9-23 dfuse -m ${MOUNTDIR} --pool $PLABEL --cont $CONT --enable-caching 2>&1

echo "dfuse -m ${MOUNTDIR} --pool ${PLABEL} --cont ${CLABEL} ${DFUSECACHE}"
dfuse -m ${MOUNTDIR} --pool ${PLABEL} --cont ${CLABEL} ${DFUSECACHE} 2>&1 

OUT=$(mount | grep dfuse | wc -l)

if [[ ${OUT} -eq 0 ]]; then
  rm -rf ${MOUNTDIR}
else
  echo Dfuse mount successful on $(hostname)
fi

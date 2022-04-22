#!/bin/sh

clush --hostfile=${CLI_HOSTLIST} "fusermount -u ${MOUNTDIR}"
clush --hostfile=${CLI_HOSTLIST} "killall -9 dfuse"
clush --hostfile=${CLI_HOSTLIST} "pkill dfuse"
clush --hostfile=${CLI_HOSTLIST} "pkill dfuse"
clush --hostfile=${CLI_HOSTLIST} "killall -9 daos_agent"
clush --hostfile=${CLI_HOSTLIST} "pkill daos_agent"
clush --hostfile=${CLI_HOSTLIST} "pkill daos_agent"
clush --hostfile=${CLI_HOSTLIST} "fusermount -u ${MOUNTDIR}"
clush --hostfile=${CLI_HOSTLIST} "rm -rf ${MOUNTDIR}"

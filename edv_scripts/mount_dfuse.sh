#! /bin/bash

#Globals update appropriately.
ENVFILE=/opt/crtdc/daos/master/vishwana/centos8/env.sh
BINDIR=/opt/crtdc/daos/master/vishwana/centos8/bin/
CONFIGDIR=/opt/crtdc/daos/master/vishwana/config/vishwana

# Source environments
source ${ENVFILE} 

# Extract nodelist/hostfile
if [ -z "$2" ]; then
	list=`squeue | grep $USER | grep -v priority | awk '{print $1;exit}'`
	hf="nodefile.${list}"
	echo ${hf}
else
	hf=$2
fi

clush --hostfile ${hf} 'fusermount -u /daos/vishwana'

# Total clients from hostfile
cnodes=`wc -l ${hf} | awk '{print $1}'`
echo "Total nodes : ${cnodes}"
RUN_DIR=`pwd`

# Global defaults
export FI_UNIVERSE_SIZE=16383

# DAOS agent setup
clush --hostfile ${hf} 'killall daos_agent'
clush --hostfile ${hf} "mkdir -p /tmp/daos_agent-$USER/ && mkdir -p /tmp/$USER/"
clush --hostfile ${hf} "export HWLOC_HIDE_ERRORS=1 && source ${ENVFILE} && ${BINDIR}/daos_agent -o ${CONFIGDIR}/daos_agent_$1.yml" &

echo "Wait for DAOS AGENTS to start"
sleep 5
echo "Proceed!"

POOL_UUID=`dmg -o ${CONFIGDIR}/daos_control_$1.yml pool list | awk '{print $1}' | egrep -v "\---------|Pool"`
echo -e "POOL " ${POOL_UUID}
if [ -z ${3} ]; then
	cont=`daos container create --pool=${POOL_UUID} --type=POSIX | awk '{print $4}'`
else
	echo -e "Container exists $2"
	cont=$2
fi

echo -e "Container " $cont
clush --hostfile ${hf} 'mkdir -p /daos/vishwana'
clush --hostfile ${hf} 'fusermount -u /daos/vishwana'
clush --hostfile ${hf} "dfuse -m /daos/vishwana --pool ${POOL_UUID} --container $cont --disable-caching"

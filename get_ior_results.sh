#!/bin/bash

if [ $# -eq 0 ] ; then
    echo "Usage: $0 <full path to results directory>"
    exit 1
fi

RES_DIR=$1

if [[ ! -d "$RES_DIR" ]] ;  then
    echo "Result directory $RES_DIR does not exist" 
    exit 1
fi

cd $RES_DIR

#Test name
current=${PWD##*/}
echo $current

#Output file
result=${RES_DIR}/result_${current}.csv

# Extract results from test logs

function get_value(){
    grep -E "^${1}[[:space:]]*:\s" ${2} | cut -d ':' -f 2 | tr -d ' '
}

echo "Servers,Clients,PPC,Ranks,Scenario,Max Write (GiB/sec),Max Read (GiB/sec),Start,End,Status" > ${result}

# For each directory in the curret dir, if the name starts with log
# get the run configuration parameters 
# if the run was successful (i.e. have Max Write in ior output file) 
# extract and output the results in csv format
# for unsuccessful runs output 0 for values.
for i in *
do
    if [ -d "$i" ] && [[ "$i" = log* ]]; then
        CURRENT_FILE=${RES_DIR}/$i/stdout*
        SERVERS=$(grep -E "^DAOS_SERVERS=" ${CURRENT_FILE} | cut -d '=' -f 2 | tr -d ' ')
        CLIENTS=$(get_value 'nodes' ${CURRENT_FILE})
        RANKS=$(get_value 'tasks' ${CURRENT_FILE})
        PPC=$(get_value 'clients per node' ${CURRENT_FILE})
        SCENARIO=$(get_value 'RUN' ${CURRENT_FILE})
        START_TIME=$(grep -E "^Start Time:\s" ${CURRENT_FILE} | sed "s/Start Time: //g")
        END_TIME=$(grep -E "^End Time:\s" ${CURRENT_FILE} | sed "s/End Time: //g")

        if [ -f "$i"/stdout* ] && grep -q "Max Write" "$i"/stdout* ; then
            wr=`grep "Max Write" ./$i/stdout* | awk '{print $3}'`
            rd=`grep "Max Read" ./$i/stdout* | awk '{print $3}'`
            wr_GiB=`echo "scale=2;$wr / 1024" | bc`
            rd_GiB=`echo "scale=2;$rd / 1024" | bc`
            echo "${SERVERS},${CLIENTS},${PPC},${RANKS},${SCENARIO},${wr_GiB},${rd_GiB},${START_TIME},${END_TIME},Passed" >> ${result}
        else
            echo "${SERVERS},${CLIENTS},${PPC},${RANKS},${SCENARIO},0,0,${START_TIME},${END_TIME},Failed" >> ${result}
        fi
    fi
done

echo " Done.  Results in $result"

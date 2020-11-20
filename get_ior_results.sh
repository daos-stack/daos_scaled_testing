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
echo
echo "Test Name: ${current}"
echo

#Output file
result=${RES_DIR}/result_${current}.csv

# Extract results from test logs

function get_value(){
    grep -E "^${1}[[:space:]]*:\s" ${2} | cut -d ':' -f 2 | tr -d ' ' | head -1
}

function get_ior_metric(){
    local LOG_FILE="${1}"
    local VALUE_LABEL="${2}"
    local op_GiB=0

    if [ -f "${LOG_FILE}" ] && grep -q "${VALUE_LABEL}" ${LOG_FILE} ; then
        local op=`grep "${VALUE_LABEL}" ${LOG_FILE} | awk '{print $3}'`
        local op_GiB=`echo "scale=2;$op / 1024" | bc`
    fi

    echo "${op_GiB}"
}

function get_status(){
    local MAX_READ=${1}
    local MAX_WRITE=${2}

    if (( $(echo "${MAX_WRITE} > 0" | bc -l) )) && (( $(echo "${MAX_READ} > 0" | bc -l) )); then
        echo "Passed"
    elif (( $(echo "${MAX_WRITE} > 0" | bc -l) )) || (( $(echo "${MAX_READ} > 0" | bc -l) )); then
        echo "Warning"
    else
        echo "Failed"
    fi
}

function get_time_stamp(){
    local LOG_FILE="${1}"
    local VALUE_LABEL="${2}"

    local TIME=$(grep -E "^${VALUE_LABEL}:\s" ${LOG_FILE} | sed "s/${VALUE_LABEL}:\s//g")

    date -d "${TIME}" +"%m/%d/%Y %H:%M:%S"
}

function update_csv(){
    local CURRENT_FILE=${1}
    local RESULT_FILE=${2}

    echo "  reaing file: ${CURRENT_FILE}"

    SERVERS=$(grep -E "^DAOS_SERVERS=" ${CURRENT_FILE} | cut -d '=' -f 2 | tr -d ' ')
    CLIENTS=$(get_value 'nodes' ${CURRENT_FILE})
    RANKS=$(get_value 'tasks' ${CURRENT_FILE})
    PPC=$(get_value 'clients per node' ${CURRENT_FILE})
    SCENARIO=$(get_value 'RUN' ${CURRENT_FILE})
    START_TIME="$(get_time_stamp ${CURRENT_FILE} "Start Time")"
    END_TIME="$(get_time_stamp ${CURRENT_FILE} "End Time")"
    wr_GiB="$(get_ior_metric ${CURRENT_FILE} "Max Write")"
    rd_GiB="$(get_ior_metric ${CURRENT_FILE} "Max Read")"
    STATUS="$(get_status ${wr_GiB} ${rd_GiB})"

    echo "${SERVERS},${CLIENTS},${PPC},${RANKS},${SCENARIO},${wr_GiB},${rd_GiB},${START_TIME},${END_TIME},${STATUS}" >> ${result}
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
        FILES=$(find ${RES_DIR}/$i -type f -name "stdout*")

        for j in ${FILES}
        do
            if [ -z ${j} ]; then
                continue
            fi

            update_csv ${j} $result
        done
    fi
done

echo
echo " Done.  Results in $result"

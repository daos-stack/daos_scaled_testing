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
    grep -E "^${1}" ${2} | cut -d "${3}" -f ${4} | tr -d ' '
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

    echo "  reading file: ${CURRENT_FILE}"

    SERVERS=$(get_value "DAOS_SERVERS=" ${CURRENT_FILE} = 2)
    RANKS=$(get_value "mdtest.*was launched" ${CURRENT_FILE} ' ' 5)
    CLIENTS=$(get_value "mdtest.*was launched" ${CURRENT_FILE} ' ' 9)
    SCENARIO=$(get_value "RUN[[:space:]]*:\s" ${CURRENT_FILE} : 2)
    START_TIME="$(get_time_stamp ${CURRENT_FILE} "Start Time")"
    END_TIME="$(get_time_stamp ${CURRENT_FILE} "End Time")"

    if [ -f "${CURRENT_FILE}" ] && grep -q "SUMMARY rate" "${CURRENT_FILE}" ; then
        cr=`grep -A 11 "SUMMARY rate:" ${CURRENT_FILE} | grep "File creation" | awk '{print $6}'`
        st=`grep -A 11 "SUMMARY rate:" ${CURRENT_FILE} | grep "File stat" | awk '{print $6}'`
        rd=`grep -A 11 "SUMMARY rate:" ${CURRENT_FILE} | grep "File read" | awk '{print $6}'`
        rl=`grep -A 11 "SUMMARY rate:" ${CURRENT_FILE} | grep "File removal" | awk '{print $6}'`

        cr_Kop=`echo "scale=2;$cr / 1000" | bc`
        st_Kop=`echo "scale=2;$st / 1000" | bc`
        rd_Kop=`echo "scale=2;$rd / 1000" | bc`
        rm_Kop=`echo "scale=2;$rl / 1000" | bc`

        echo "${SERVERS},${CLIENTS},${RANKS},${SCENARIO},${cr_Kop},${st_Kop},${rd_Kop},${rm_Kop},${cr},${st},${rd},${rl},${START_TIME},${END_TIME},Passed" >> ${RESULT_FILE}

    else
        echo "${SERVERS},${CLIENTS},${RANKS},${SCENARIO},0,0,0,0,0,0,0,0,${START_TIME},${END_TIME},Failed" >> ${RESULT_FILE}
    fi
}

echo "Servers,Clients,Ranks,Scenario,create(Kops/sec),stat(Kops/sec),read(Kops/sec),remove(Kops/sec),creates/sec,stat/sec,reads/sec,remove/sec,Start,End,Status" > ${result}

# For each directory in the curret dir, if the name starts with log
# get the run configuration parameters
# if the run was successful (i.e. have SUMMARY rate in ior output file)
# extract and output the results in csv format
# for unsuccessful runs output 0 for values.

for i in *
do
    if [ -d "$i" ] && [[ "$i" = log* ]]; then
        FILES="$(find ${RES_DIR}/$i -type f -name "stdout*")"

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

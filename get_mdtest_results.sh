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
    grep -E "^${1}" ${2} | cut -d "${3}" -f ${4} | tr -d ' '
}

echo "Servers,Clients,Ranks,Scenario,create(Kops/sec),stat(Kops/sec),read(Kops/sec),remove(Kops/sec),creates/sec,stat/sec,reads/sec,remove/sec,Start,End,Status" > $result

# For each directory in the curret dir, if the name starts with log
# get the run configuration parameters
# if the run was successful (i.e. have SUMMARY rate in ior output file)
# extract and output the results in csv format
# for unsuccessful runs output 0 for values.

for i in *
do
    if [ -d "$i" ] && [[ "$i" = log* ]]; then
        CURRENT_FILE=${RES_DIR}/$i/stdout*
        SERVERS=$(get_value "DAOS_SERVERS=" ${CURRENT_FILE} = 2)
        RANKS=$(get_value "mdtest.*was launched" ${CURRENT_FILE} ' ' 5)
        CLIENTS=$(get_value "mdtest.*was launched" ${CURRENT_FILE} ' ' 9)
        SCENARIO=$(get_value "RUN[[:space:]]*:\s" ${CURRENT_FILE} : 2)
        START_TIME=$(grep -E "^Start Time:\s" ${CURRENT_FILE} | sed "s/Start Time: //g")
        END_TIME=$(grep -E "^End Time:\s" ${CURRENT_FILE} | sed "s/End Time: //g")

        if [ -f "$i"/stdout* ] && grep -q "SUMMARY rate" "$i"/stdout* ; then
            cr=`grep -A 11 "SUMMARY rate:" ./$i/stdout* | grep "File creation" | awk '{print $6}'`
            st=`grep -A 11 "SUMMARY rate:" ./$i/stdout* | grep "File stat" | awk '{print $6}'`
            rd=`grep -A 11 "SUMMARY rate:" ./$i/stdout* | grep "File read" | awk '{print $6}'`
            rl=`grep -A 11 "SUMMARY rate:" ./$i/stdout* | grep "File removal" | awk '{print $6}'`

            cr_Kop=`echo "scale=2;$cr / 1000" | bc`
            st_Kop=`echo "scale=2;$st / 1000" | bc`
            rd_Kop=`echo "scale=2;$rd / 1000" | bc`
            rm_Kop=`echo "scale=2;$rl / 1000" | bc`

            echo "${SERVERS},${CLIENTS},${RANKS},${SCENARIO},${cr_Kop},${st_Kop},${rd_Kop},${rm_Kop},${cr},${st},${rd},${rl},${START_TIME},${END_TIME},Passed" >> $result

        else
            echo "${SERVERS},${CLIENTS},${RANKS},${SCENARIO},0,0,0,0,0,0,0,0,${START_TIME},${END_TIME},Failed" >> $result
        fi
    fi
done

echo " Done.  Results in $result"

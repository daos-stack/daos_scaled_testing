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

#Output file
result="$RES_DIR/result_$current"

# Extract results from test logs

echo "Num_Servers,create(Kops/sec),stat(Kops/sec),read(Kops/sec),remove(Kops/sec),creates/sec,stat/sec,reads/sec,remove/sec" > $result

# For each directory in the curret dir, if the name starts with log
# get the run configuration parameters
# if the run was successful (i.e. have SUMMARY rate in ior output file)
# extract and output the results in csv format
# for unsuccessful runs output 0 for values.

for i in *
do
    if [ -d "$i" ] && [[ "$i" = log* ]]; then
        str=`grep num_servers ./$i/stdout*`
        servers=`awk '{print $2}' <<< "$str"`
        targets=`awk '{print $4}' <<< "$str"`
        clients=`awk '{print $6}' <<< "$str"`
        ranks=`awk '{print $8}' <<< "$str"`

        if [ -f "$i"/mdtest* ] && grep "SUMMARY rate" "$i"/mdtest* ; then
            cr=`grep -A 6 "SUMMARY rate:" ./$i/mdtest* | grep "File creation" | awk '{print $6}'`
            st=`grep -A 6 "SUMMARY rate:" ./$i/mdtest* | grep "File stat" | awk '{print $6}'`
            rd=`grep -A 6 "SUMMARY rate:" ./$i/mdtest* | grep "File read" | awk '{print $6}'`
            rl=`grep -A 6 "SUMMARY rate:" ./$i/mdtest* | grep "File removal" | awk '{print $6}'`

            cr_Kop=`echo "scale=2;$cr / 1000" | bc`
            st_Kop=`echo "scale=2;$st / 1000" | bc`
            rd_Kop=`echo "scale=2;$rd / 1000" | bc`
            rm_Kop=`echo "scale=2;$rl / 1000" | bc`

            echo "$servers","$cr_Kop","$st_Kop","$rd_Kop","$rm_Kop","$cr","$st","$rd","$rl" >> $result

        else
            echo "$servers",0,0,0,0,0,0,0,0 >> $result
        fi
    fi
done

echo " Done.  Results in $result"

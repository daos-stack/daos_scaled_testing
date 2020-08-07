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
result="$RES_DIR/result_$current"

# Extract results from test logs

echo Num_Servers,Targets,Clients,Ranks,Write-Easy,Read-Easy > $result

for i in *
do
    if [ -d "$i" ] && [[ "$i" = log* ]]; then
       if [ -f "$i"/ior* ] && grep "Max Write" "$i"/ior* ; then
           str=`grep num_servers ./$i/stdout*`
           servers=`awk '{print $2}' <<< "$str"`
           targets=`awk '{print $4}' <<< "$str"`
           clients=`awk '{print $6}' <<< "$str"`
           ranks=`awk '{print $8}' <<< "$str"`
           wr=`grep  "Max Write" ./$i/ior* | awk '{print $3}'`
           rd=`grep "Max Read" ./$i/ior* | awk '{print $3}'`
           wr_GiB=`echo "scale=2;$wr / 1024" | bc`
           rd_GiB=`echo "scale=2;$rd / 1024" | bc`
           echo "$servers","$wr_GiB","$rd_GiB","$wr","$rd" >> $result
       fi
    fi

done

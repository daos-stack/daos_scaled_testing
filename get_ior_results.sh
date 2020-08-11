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

# For each directory in the curret dir, if the name starts with log
# get the run configuration parameters 
# if the run was successful (i.e. have Max Write in ior output file) 
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
       if [ -f "$i"/ior* ] && grep "Max Write" "$i"/ior* ; then
           wr=`grep  "Max Write" ./$i/ior* | awk '{print $3}'`
           rd=`grep "Max Read" ./$i/ior* | awk '{print $3}'`
           wr_GiB=`echo "scale=2;$wr / 1024" | bc`
           rd_GiB=`echo "scale=2;$rd / 1024" | bc`
           echo "$servers","$wr_GiB","$rd_GiB","$wr","$rd" >> $result
       else
          echo "$servers",0,0,0,0 >> $result
       fi
    fi
done

echo " Done.  Results in $result"

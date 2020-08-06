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

#Output files - raw* for extracting the results from tests and result* for final results in csv format into a file ready for plotting
raw="./raw_$current"
result="./result_$current"

process_result() {
    infile=$1
    outfile=$2
    if [ -f ./tmp ] ; then rm ./tmp ; fi
    echo "Num_Servers,Write(GiB/s),Read(GiB/s),Write(MiB/s),Read(MiB/s)" > $outfile
    {
        last=0
        {
        read
        while  read -r line ; do
            cur=`awk -F, '{print $1}' <<< "$line"`
            wr=`awk -F, '{print $5}' <<< "$line"`
            rd=`awk -F, '{print $6}' <<< "$line"`
            if  [[ $cur -ne $last ]] ; then
                calc_averages  $cnt  
                last=$cur
                cnt=1
                sum_wr=$wr
                sum_rd=$rd
            else
                let "cnt++"
                sum_wr=`echo "$sum_wr + $wr" | bc`
                sum_rd=`echo "$sum_rd + $rd" | bc`
            fi
        done
        }  < "$infile"
        calc_averages  $cnt 
        echo $infile $outfile
    }
    cat tmp | tee -a  $outfile
}

calc_averages () {
    num=$1
    if [[  $last -ne "0" ]] ; then
    av_wr=`echo "scale=2;$sum_wr / $num" | bc`
    av_rd=`echo "scale=2;$sum_rd / $num" | bc`
    wr_GiB=`echo "scale=2;$av_wr / 1024" | bc`
    rd_GiB=`echo "scale=2;$av_rd / 1024" | bc`
    echo "$last","$wr_GiB","$rd_GiB","$av_wr","$av_rd" >> tmp
    fi
}

# Extract results from test logs

echo Num_Servers,Targets,Clients,Ranks,Write-Easy,Read-Easy > $raw

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
           echo "$servers","$targets","$clients","$ranks","$wr","$rd" >> $raw
       fi
    fi

done

#Generate result files in plot firendly format

process_result $raw $result

#cleanup
rm ./tmp

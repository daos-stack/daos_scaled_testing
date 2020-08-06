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
    echo "Num_Servers,create(Kops/sec),stat(Kops/sec),read(Kops/sec),rm(Kops/sec),creates/sec,stat/sec,reads/sec,rms/sec" > $outfile
    {
        last=0
        {
        read
        while  read -r line ; do
            cur=`awk -F, '{print $1}' <<< "$line"`
            cr=`awk -F, '{print $5}' <<< "$line"`
            st=`awk -F, '{print $6}' <<< "$line"`
            rd=`awk -F, '{print $7}' <<< "$line"`
            rm=`awk -F, '{print $8}' <<< "$line"`
            if  [[ $cur -ne $last ]] ; then
                calc_averages  $cnt
                last=$cur
                cnt=1
                sum_cr=$cr
                sum_st=$st
                sum_rd=$rd
                sum_rm=$rm
            else
                let "cnt++"
                sum_cr=`echo "$sum_cr + $cr" | bc`
                sum_st=`echo "$sum_st + $st" | bc`
                sum_rd=`echo "$sum_rd + $rd" | bc`
                sum_rm=`echo "$sum_rm + $rm" | bc`
            fi
        done
        }  < $infile
        calc_averages  $cnt
        echo 
    }
    cat tmp | tee -a  $outfile
}

calc_averages () {
    num=$1
    if [[  $last -ne "0" ]] ; then
    av_cr=`echo "scale=2;$sum_cr / $num" | bc`
    av_st=`echo "scale=2;$sum_st / $num" | bc`
    av_rd=`echo "scale=2;$sum_rd / $num" | bc`
    av_rm=`echo "scale=2;$sum_rm / $num" | bc`
    cr_Kop=`echo "scale=2;$av_cr / 1000" | bc`
    st_Kop=`echo "scale=2;$av_st / 1000" | bc`
    rd_Kop=`echo "scale=2;$av_rd / 1000" | bc`
    rm_Kop=`echo "scale=2;$av_rm / 1000" | bc`
    echo "$last","$cr_Kop","$st_Kop","$rd_Kop","$rm_Kop","$av_cr","$av_st","$av_rd","$av_rm" >> tmp
    fi
}

# Extract results from test logs

echo Num_Servers,Targets,Clients,Ranks,create/sec,stat/sec,read/sec,remove/sec >> $raw

for i in *
do
    if [ -d "$i" ] && [[ "$i" = log* ]]; then
        if [ -f "$i"/mdtest* ] && grep "SUMMARY rate" "$i"/mdtest* ; then
            str=`grep num_servers ./$i/stdout*`
            servers=`awk '{print $2}' <<< "$str"`
            targets=`awk '{print $4}' <<< "$str"`
            clients=`awk '{print $6}' <<< "$str"`
            ranks=`awk '{print $8}' <<< "$str"`
            output=`grep -A 6 "SUMMARY rate:" ./$i/mdtest* | grep -A 3 "File creation" | awk '{print $6}' | paste -d, - - - - `
            echo "$servers","$targets","$clients","$ranks","$output" >> $raw
        fi
    fi
done

#Generate result files in plot firendly format

process_result $raw $result

#cleanup
rm ./tmp

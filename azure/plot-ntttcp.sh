#!/bin/bash

# set -x
set -e
set -o pipefail

CWD="$(realpath "$(dirname $0)")"

source "$CWD/envs/env.sh"

RECEIVER_HOSTNAME=${1?'Missing ntttp receiver hostname'}
SENDER_NODESET=${2?'Missing ntttp sender nodeset'}
RESULTS_PATH=${3?'Missing results directory path'}
GNUPLOT_YRANGE=${4-}

rm -fr $CWD/dat
mkdir -p $CWD/dat
for dirpath in $(find "$RESULTS_PATH" -type d -links 2) ; do
	echo "Processing $dirpath"

	receiver_throughputs=$(cat $dirpath/ntttcp-$RECEIVER_HOSTNAME.json | jq -r '.ntttcpr.throughputs[] | select(.metric=="MB/s") | .value')

	(( min=(2**63) - 1 ))
	max=0
	mean=0
	sender_nb=0
	for hostname in $($NODESET_BIN -e $SENDER_NODESET) ; do
		filepath=$dirpath/ntttcp-$hostname.json
		if [[ ! -f $filepath ]] ; then
			continue
		fi

		throughputs=$(cat $filepath | jq -r '.ntttcps.throughputs[] | select(.metric=="MB/s") | .value')
		if (( $(echo "$min > $throughputs" | bc -l)  )) ; then
			min=$throughputs
		fi
		if (( $(echo "$max < $throughputs" | bc -l) )) ; then
			max=$throughputs
		fi
		mean=$(echo "$mean + $throughputs" | bc -l)
		(( sender_nb=$sender_nb + 1 ))
	done
	mean=$(echo "$mean / $sender_nb" | bc -l)

	mean=$(echo "$mean * .953674" | bc -l)
	min=$(echo "$min * .953674" | bc -l)
	max=$(echo "$max * .953674" | bc -l)

	echo "$sender_nb;$receiver_throughputs" >> $CWD/dat/ntttcp-receiver.dat
	echo "$sender_nb;$mean;$min;$max" >> $CWD/dat/ntttcp-sender.dat
done

for filepath in $CWD/dat/* ; do
	sort -n < $filepath > $filepath.new
	cat $filepath.new > $filepath
	rm -f $filepath.new
done

rm -fr gpi png
mkdir gpi png
filename=ntttcp
echo "Generating graph file $filename"

file_gpi=$CWD/gpi/$filename.gpi
file_png=$CWD/png/$filename.png

if [[ $GNUPLOT_YRANGE ]] ; then
	GNUPLOT_SCALE=$(cat <<- EOF
		set autoscale x
		set yrange $GNUPLOT_YRANGE
		EOF
	)
else
	GNUPLOT_SCALE="set autoscale xy"
fi

cat > $file_gpi <<- EOF
set border 3
set xtics mirror
set ytics mirror
set grid xtics ytics
$GNUPLOT_SCALE
set encoding iso_8859_1
set datafile separator ";"

set xlabel "Sender Number"
set ylabel "Throughputs (MiB/s)"

set term png transparent interlace lw 2 large size 1280,1024
set title "NTTTCP Network Throughputs"
set output "$file_png"
# set term x11 title "IOR: type=$test_type file_mode=$file_mode"

plot '$CWD/dat/ntttcp-receiver.dat' using 1:2 with lines axes x1y1 title 'Receiver: $RECEIVER_HOSTNAME', \\
     '$CWD/dat/ntttcp-sender.dat' using 1:2:3:4 with yerrorlines axes x1y1 title 'Sender: $SENDER_NODESET'
EOF

gnuplot -p $file_gpi

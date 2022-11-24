#!/bin/bash

# set -x
set -e
set -o pipefail

CWD="$(realpath "$(dirname $0)")"

source "$CWD/envs/env.sh"

RESULTS_PATH=${1?'Missing results directory path'}

FILE_NAME=self_test

for dir_path in "$CWD/dat/" "$CWD/gpi/" "$CWD/png/" ; do
	mkdir -p "$dir_path"
done

for item in latency throughput ; do
	> "$CWD/dat/${FILE_NAME}-$item.dat"
done
for file in $(find "$RESULTS_PATH" -maxdepth 1 -type f -name "self_test-*.log") ; do

	endpoint_nb=$(( 1 + $(cut -d- -f2 <<< "$(basename "$file" .log)") ))

	latency_avg=$(grep -e "Average:" "$file" | awk -e '{ print $2 }' | head -n1)
	latency_min=$(grep -e "Min    :" "$file" | awk -e '{ print $3 }' | head -n1)
	latency_med=$(grep -e "Median :" "$file" | awk -e '{ print $3 }' | head -n1)
	latency_max=$(grep -e "Max    :" "$file" | awk -e '{ print $3 }' | head -n1)
	latency_sdv=$(grep -e "Std Dev:" "$file" | awk -e '{ print $3 }' | head -n1)

	throughput_read=$(grep -e "RPC Bandwidth" "$file" | sed -n -E -e '3s/^[[:space:]]+RPC Bandwidth .+: ([[:digit:]]+\.[[:digit:]]+)$/\1/p')
	throughput_read=$(bc -l <<< "$throughput_read * .953674")
	throughput_write=$(grep -e "RPC Bandwidth" "$file" | sed -n -E -e '2s/^[[:space:]]+RPC Bandwidth .+: ([[:digit:]]+\.[[:digit:]]+)$/\1/p')
	throughput_write=$(bc -l <<< "$throughput_write * .953674")
	throughput_rw=$(grep -e "RPC Bandwidth" "$file" | sed -n -E -e '4s/^[[:space:]]+RPC Bandwidth .+: ([[:digit:]]+\.[[:digit:]]+)$/\1/p')
	throughput_rw=$(bc -l <<< "$throughput_rw * .953674")

	echo "$endpoint_nb;$throughput_read;$throughput_write;$throughput_rw" >> "$CWD/dat/${FILE_NAME}-throughput.dat"
	echo "$endpoint_nb;$latency_avg;$latency_min;$latency_med;$latency_max;$latency_sdv" >> "$CWD/dat/${FILE_NAME}-latency.dat"
done

for item in latency throughput ; do
	filepath="$CWD/dat/${FILE_NAME}-$item.dat"
	sort -n < $filepath > $filepath.new
	cat $filepath.new > $filepath
	rm -f $filepath.new
done

file_gpi="$CWD/gpi/$FILE_NAME-throughput.gpi"
file_png="$CWD/png/$FILE_NAME-throughput.png"
cat > "$file_gpi" <<- EOF
set border 3
set xtics mirror
set ytics mirror
set grid xtics ytics
set autoscale x
set yrange [0:*]
set datafile separator ";"
set encoding iso_8859_1

set xlabel "End Point Number"
set ylabel "Throughputs (MiB/s)"

set term png transparent interlace lw 2 giant size 1280,1024
set title "CART SelfTest Throughputs"
set output "$file_png"

plot '$CWD/dat/$FILE_NAME-throughput.dat' using 1:2 with lines axes x1y1 title 'Read (0MiB-1MiB)', \\
     '$CWD/dat/$FILE_NAME-throughput.dat' using 1:3 with lines axes x1y1 title 'Write (1MiB-0MiB)', \\
     '$CWD/dat/$FILE_NAME-throughput.dat' using 1:4 with lines axes x1y1 title 'Read-Write (1MiB-1MiB)'
EOF
gnuplot -p "$file_gpi"

file_gpi="$CWD/gpi/$FILE_NAME-latency.gpi"
file_png="$CWD/png/$FILE_NAME-latency.png"
cat > "$file_gpi" <<- EOF
set border 3
set xtics mirror
set ytics mirror
set grid xtics ytics
set autoscale x
set yrange [0:*]
set datafile separator ";"
set encoding iso_8859_1

set xlabel "End Point Number"
set ylabel "Latency (us)"

set term png transparent interlace lw 2 giant size 1280,1024
set title "CART SelfTest Latencies"
set output "$file_png"

plot '$CWD/dat/$FILE_NAME-latency.dat' using 1:2 with lines axes x1y1 title 'Average', \\
     '$CWD/dat/$FILE_NAME-latency.dat' using 1:4 with lines axes x1y1 title 'Median', \\
     '$CWD/dat/$FILE_NAME-latency.dat' using 1:6 with lines axes x1y1 title 'Standard Deviation'
EOF
gnuplot -p "$file_gpi"

file_gpi="$CWD/gpi/$FILE_NAME-latency_dispersion.gpi"
file_png="$CWD/png/$FILE_NAME-latency_dispersion.png"
cat > "$file_gpi" <<- EOF
set border 3
set xtics mirror
set ytics mirror
set grid xtics ytics
set xrange [0.8:10.2]
set autoscale y
set logscale y
set datafile separator ";"
set encoding iso_8859_1

set xlabel "End Point Number"
set ylabel "Latency (us)"

set term png transparent interlace lw 2 giant size 1280,1024
set title "CART SelfTest Latencies Dispersion"
set output "$file_png"

plot '$CWD/dat/$FILE_NAME-latency.dat' using 1:4:3:5 with yerrorlines axes x1y1 title 'Median with Min-Max', \\
     '$CWD/dat/$FILE_NAME-latency.dat' using 1:6 with lines axes x1y1 title 'Standard Deviation'
EOF
gnuplot -p "$file_gpi"

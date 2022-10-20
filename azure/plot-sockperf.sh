#!/bin/bash

# set -x
set -e
set -o pipefail

CWD="$(realpath "$(dirname $0)")"

source "$CWD/envs/env.sh"

RESULTS_PATH=${1?'Missing results directory path'}
GNUPLOT_YRANGE=${2-}

FILE_PATHS=(
"$RESULTS_PATH/sockperf-client_client.log"
"$RESULTS_PATH/sockperf-client_server.log"
"$RESULTS_PATH/sockperf-server_client.log"
"$RESULTS_PATH/sockperf-server_server.log"
)

BAR_NAMES=(
"clt-clt"
"clt-svr"
"svr-clt"
"svr-svr"
)

FILE_NAME=sockperf

file_dat="$CWD/dat/$FILE_NAME.dat"
file_gpi="$CWD/gpi/$FILE_NAME.gpi"
file_png="$CWD/png/$FILE_NAME.png"

for dir_path in "$CWD/dat/" "$CWD/gpi/" "$CWD/png/" ; do
	mkdir -p "$dir_path"
done

> "$file_dat"
for index in {0..3} ; do
	iops=$(sed -n -E -e 's/^sockperf: Summary: Latency is ([[:digit:].]+) usec.*$/\1/p' "${FILE_PATHS[$index]}")
	echo "$index;${BAR_NAMES[$index]};$iops" >> "$file_dat"
done

if [[ $GNUPLOT_YRANGE ]] ; then
	GNUPLOT_SCALE=$(cat <<- EOF
		set autoscale x
		set yrange $GNUPLOT_YRANGE
		EOF
	)
else
	GNUPLOT_SCALE="set autoscale xy"
fi

cat > "$file_gpi" <<- EOF
set border 3
set xtics nomirror
set ytics nomirror
set grid ytics
$GNUPLOT_SCALE
set encoding iso_8859_1
set datafile separator ";"
set boxwidth 0.5
set style fill solid

set ylabel "Latencies (usec)"

set term png transparent interlace lw 2 giant size 1280,1024
set title "SockPerf Network Latencies"
set output "$file_png"

plot '$file_dat' using 1:3:xtic(2) with boxes notitle
EOF

gnuplot -p "$file_gpi"

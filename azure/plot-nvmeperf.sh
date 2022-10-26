#!/bin/bash

# set -x
set -e
set -o pipefail

CWD="$(realpath "$(dirname $0)")"

source "$CWD/envs/env.sh"

RESULTS_PATH=${1?'Missing results directory path'}
GNUPLOT_YRANGE=${2-}

declare -A METRIC_NAMES=(
[4096]=iops
[1048576]=throughput
)

declare -A METRIC_FIELDS=(
[4096]=3
[1048576]=4
)

declare -A METRIC_UNITS=(
[4096]=IOPS
[1048576]=MiB/s
)

if [[ $GNUPLOT_YRANGE ]] ; then
	GNUPLOT_SCALE=$(cat <<- EOF
		set autoscale x
		set yrange $GNUPLOT_YRANGE
		EOF
	)
else
	GNUPLOT_SCALE="set autoscale xy"
fi

for size in 4096 1048576 ; do
	metric=${METRIC_NAMES[$size]}
	for operation in write read ; do
		file_dat="$CWD/dat/spdk_nvme_perf-$metric-$operation.dat"
		> $file_dat
		avg_acc=0
		avg_nb=0
		for file_log in $(find "$RESULTS_PATH" -type f -name "spdk_nvme_perf-${size}-$operation.log.*" -print) ; do
			hostname=${file_log##*.}
			index=${hostname#daos-serv0000}
			value=$(grep -E -e "^Total[[:space:]]+:[[:space:]]+.*" "$file_log" | sed -E -e 's/[[:space:]]+/ /g' | cut -d' ' -f ${METRIC_FIELDS[$size]})
			echo "$index;$hostname;$value" >> $file_dat
			avg_acc=$(bc <<< "$avg_acc + $value")
			((avg_nb++)) || true
		done
		echo "# metric=$metric operation=$operation avg=$(bc <<< "$avg_acc / $avg_nb") ${METRIC_UNITS[$size]}"

		sort -n < $file_dat > $file_dat.new
		cat $file_dat.new > $file_dat
		rm -f $file_dat.new

		file_gpi="$CWD/gpi/spdk_nvme_perf-$metric-$operation.gpi"
		file_png="$CWD/png/spdk_nvme_perf-$metric-$operation.png"
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

		set ylabel "$metric (${METRIC_UNITS[$size]})"

		set term png transparent interlace lw 2 giant size 1280,1024
		set title "NVMe $metric performance"
		set output "$file_png"

		plot '$file_dat' using 1:3:xtic(1) with boxes notitle
		EOF

		gnuplot -p "$file_gpi"
	done
done

#!/bin/bash

# set -x
set -e
set -o pipefail

CWD="$(realpath "$(dirname $0)")"

source "$CWD/envs/env.sh"

RESULTS_PATH=${1?'Missing results directory path'}

for dirname in dat gpi png ; do
	mkdir -p "$CWD/$dirname/self_test-servers_nb" "$CWD/$dirname/self_test-inflight_rpc"
done

GNUPLOT_TITLE=${2:?'Missing gnuplot title'}

GNUPLOT_YRANGE=${3-}


# Processing results file

max_selftest="0:0:0"
declare -A is_file_path_initialized
for file_path in $(find "$RESULTS_PATH" -maxdepth 1 -type f -name "self_test-*.log") ; do
	echo "Processing $file_path"

	servers_nb=$(( 1 + $(cut -d- -f2 <<< "$(basename "$file_path" .log)") ))
	inflight_rpc=$(cut -d- -f3 <<< "$(basename "$file_path" .log)")

	iops=$(sed -n -E -e "/RPC Throughput/s/^[^[:digit:]]+([[:digit:]]+)$/\1/p" $file_path)

	of="$CWD/dat/self_test-servers_nb/self_test-servers_nb-$inflight_rpc.dat"
	if [[ ${is_file_path_initialized[$of]} != true ]] ; then
		> "$of"
		is_file_path_initialized[$of]=true
	fi
	echo "$servers_nb;$iops" >> "$CWD/dat/self_test-servers_nb/self_test-servers_nb-$inflight_rpc.dat"

	max_iops=$(cut -d: -f1 <<< $max_selftest)
	if [[ $max_iops -lt $iops ]] ; then
		max_selftest="$iops:$servers_nb:$inflight_rpc"
	fi
done

echo -e "Sorting dat files"
for filepath in $(find "$CWD/dat/self_test-servers_nb" -type f -name "self_test-*.dat") ; do
	if [[ $(wc -l $filepath | awk -e '{ print $1 }') -le 1 ]] ; then
		echo "Removing useless file $filepath"
		rm $filepath
		continue
	fi
	sort -n < "$filepath" > "$filepath.new"
	cat "$filepath.new" > "$filepath"
	rm "$filepath.new"
done


# Generating self_test servers_nb graph files

if [[ $GNUPLOT_YRANGE ]] ; then
	GNUPLOT_SCALE=$(cat <<- EOF
		set autoscale x
		set yrange $GNUPLOT_YRANGE
		EOF
	)
else
	GNUPLOT_SCALE="set autoscale xy"
fi

if [[ $(find "$CWD//dat/self_test-servers_nb" -type f -name "self_test-servers_nb-*.dat" | wc -l) -gt 0 ]] ; then
	echo "Generaring self_test servers_nb graph files"
	gpi_file="$CWD/gpi/self_test-servers_nb/self_test-servers_nb.gpi"
	png_file="$CWD/png/self_test-servers_nb/self_test-servers_nb.png"
	cat > "$gpi_file" <<- EOF
	set border 11
	set xtics nomirror
	set ytics nomirror
	set y2tics nomirror
	set grid xtics ytics
	$GNUPLOT_SCALE
	set encoding iso_8859_1
	set datafile separator ";"

	set xlabel "Servers NB"
	set ylabel "RPC/sec"

	set term png transparent interlace lw 2 giant size 1280,1024
	set title "$GNUPLOT_TITLE"
	set output "$png_file"
	plot \\
	EOF
	for filepath in $(find "$CWD/dat/self_test-servers_nb" -name "self_test-servers_nb-*.dat") ; do
		filename=$(basename "$filepath" .dat)
		inflight_rpc=$(cut -d- -f3 <<< $filename)
		cat >> $gpi_file <<- EOF
		'$filepath' using 1:2 with lines axes x1y1 title 'inflight_rpc=$inflight_rpc', \\
		EOF
	done

	gnuplot -p "$gpi_file"
fi

# Print stat info

echo
echo "DAOS CaRT self_test Statistic:"
echo -e "\t- Max RPC/sec: rpc/sec=$(cut -d: -f1 <<< $max_selftest) servers_nb=$(cut -d: -f2 <<< $max_selftest) inflight_rpc=$(cut -d: -f3 <<< $max_selftest)"

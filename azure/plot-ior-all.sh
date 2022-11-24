#!/bin/bash

# set -x
set -e -o pipefail
CWD="$(realpath "$(dirname $0)")"

LOG_DIR_ROOT=${1:?'Missing logging output root directory'}
if [[ ! -d "$LOG_DIR_ROOT" ]] ; then
	echo "[ERROR] Invalid logging output root directory: $LOG_DIR_ROOT"
	exit 1
fi

declare -A max_read_throughput
declare -A max_read_oclass
declare -A max_read_dir_oclass
declare -A max_write_throughput
declare -A max_write_oclass
declare -A max_write_dir_oclass
declare -A is_file_path_initialized
for filepath in $(find "$LOG_DIR_ROOT" -type f -name "ior*.log") ; do
	echo "Processing $filepath"

	daos_oclass=$(awk -F/ '{ print $(NF-1) }' <<< "$filepath")
	daos_dir_oclass=$(awk -F/ '{ print $(NF-2) }' <<< "$filepath")
	daos_rd_fac=$(awk -F/ '{ print $(NF-3) }' <<< "$filepath")
	ior_file_sharing=$(awk -F/ '{ print $(NF-4) }' <<< "$filepath")
	ior_mode=$(awk -F/ '{ print $(NF-5) }' <<< "$filepath")

	filename=$(basename $filepath .log)
	nsvr=$(cut -d_ -f3 <<< $filename | cut -d- -f2)
	nclt=$(cut -d_ -f3 <<< $filename | cut -d- -f3)
	ppn=$(cut -d_ -f4 <<< $filename)

	read_bw=$(awk 'f;/^Summary of all tests:$/{f=1}' < $filepath | grep -E -e '^read' | sed -E -e  's/[[:space:]]+/ /g' | cut -d" " -f2)
	write_bw=$(awk 'f;/^Summary of all tests:$/{f=1}' < $filepath | grep -E -e '^write' | sed -E -e  's/[[:space:]]+/ /g' | cut -d" " -f2)

	dat_dir="$CWD/dat/ior/$ior_mode/$ior_file_sharing/$daos_rd_fac"
	mkdir -p "$dat_dir"
	file_path="$dat_dir/ior-$daos_dir_oclass-$daos_oclass-${nsvr}-${nclt}.dat"
	if [[ ${is_file_path_initialized[$file_path]} != true ]] ; then
		> "$file_path"
		is_file_path_initialized[$file_path]=true
	fi
	echo "$ppn;$read_bw;$write_bw" >> "$file_path"

	key="$ior_mode-$ior_file_sharing-$daos_rd_fac"
	if [[ -z "${max_read_throughput[$key]}" ]] || (( $(bc -l <<< "${max_read_throughput[$key]} < $read_bw") )) ; then
		max_read_throughput[$key]=$read_bw
		max_read_dir_oclass[$key]=$daos_dir_oclass
		max_read_oclass[$key]=$daos_oclass
	fi
	if [[ -z "${max_write_throughput[$key]}" ]] || (( $(bc -l <<< "${max_write_throughput[$key]} < $write_bw") )) ; then
		max_write_throughput[$key]=$write_bw
		max_write_dir_oclass[$key]=$daos_dir_oclass
		max_write_oclass[$key]=$daos_oclass
	fi

done

for filepath in $(find $CWD/dat -type f -name "*.dat") ; do
	echo -e "Sorting dat file $filepath"

	sort -n < "$filepath" > "$filepath.new"
	test_name=$(cut -d_ -f1 <<< "$filename")
	echo "# ppn read(MiB) write(MiB)" > "$filepath"
	cat "$filepath.new" >> "$filepath"
	rm "$filepath.new"
done

mkdir -p "$CWD/gpi" "$CWD/png"
for dirpath in $(find $CWD/dat/ior -type d -links 2) ; do
	daos_rd_fac=$(awk -F/ '{ print $NF }' <<< "$dirpath")
	ior_file_sharing=$(awk -F/ '{ print $(NF-1) }' <<< "$dirpath")
	ior_mode=$(awk -F/ '{ print $(NF-2) }' <<< "$dirpath")
	filename=ior-$ior_mode-$ior_file_sharing-$daos_rd_fac

	echo "Generaring graph file $filename"
	gpi_file="$CWD/gpi/$filename.gpi"
	png_file="$CWD/png/$filename-read.png"
	cat > "$gpi_file" <<- EOF
	set border 11
	set xtics nomirror
	set ytics nomirror
	set y2tics nomirror
	set grid xtics ytics
	set autoscale
	set encoding iso_8859_1
	set datafile separator ";"

	set xlabel "Processes Number"
	set ylabel "Bandwitdh (MiB/s)"

	set term png transparent interlace lw 2 giant size 1280,1024

	set title "IOR: access=read mode=$ior_mode file_sharing=$ior_file_sharing rd_fac=$daos_rd_fac"
	set output "$png_file"
	plot \\
	EOF
	for filepath in $(find "$dirpath" -name "*.dat") ; do
		oclass=$(basename $(dirname $filepath))
		daos_oclass=$(basename "$filepath" .dat | awk -F- '{ print $(NF-2) }')
		daos_dir_oclass=$(basename "$filepath" .dat | awk -F- '{ print $(NF-3) }')
		cat >> $gpi_file <<- EOF
		'$filepath' using 1:2 with lines axes x1y1 title 'read-$daos_dir_oclass-$daos_oclass', \\
		EOF
	done

	png_file="$CWD/png/${filename}-write.png"
	cat >> "$gpi_file" <<- EOF

	set title "IOR: access=write mode=$ior_mode file_sharing=$ior_file_sharing rd_fac=$daos_rd_fac"
	set output "$png_file"
	plot \\
	EOF
	for filepath in $(find "$dirpath" -name "*.dat") ; do
		oclass=$(basename $(dirname $filepath))
		daos_oclass=$(basename "$filepath" .dat | awk -F- '{ print $(NF-2) }')
		daos_dir_oclass=$(basename "$filepath" .dat | awk -F- '{ print $(NF-3) }')
		cat >> $gpi_file <<- EOF
		'$filepath' using 1:3 with lines axes x1y1 title 'write-$daos_dir_oclass-$daos_oclass', \\
		EOF
	done

	gnuplot -p "$gpi_file"
done

{
	echo "mode:file sharing:redundancy factor:read throughput:read dir_oclass:read oclass:write throughput:write dir_oclass:write oclass"
	for key in ${!max_read_throughput[*]} ; do
		daos_rd_fac=$(awk -F- '{ print $NF }' <<< "$key")
		ior_file_sharing=$(awk -F- '{ print $(NF-1) }' <<< "$key")
		ior_mode=$(awk -F- '{ print $(NF-2) }' <<< "$key")
		echo -n "$ior_mode:$ior_file_sharing:$daos_rd_fac:"
		echo -n "$(bc -l <<< "scale=2; ${max_read_throughput[$key]} * 0.000976562 / 1") GiB/s (${max_read_throughput[$key]} MiB/s):${max_read_dir_oclass[$key]}:${max_read_oclass[$key]}:"
		echo "$(bc -l <<< "scale=2; ${max_write_throughput[$key]} * 0.000976562 / 1") GiB/s (${max_write_throughput[$key]} MiB/s):${max_write_dir_oclass[$key]}:${max_write_oclass[$key]}:"
	done
} | column -s ':' -t | (sed -u 1q; sort)

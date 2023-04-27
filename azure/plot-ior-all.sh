#!/bin/bash

# set -x
set -e -o pipefail
CWD="$(realpath "$(dirname $0)")"

LOG_DIR_ROOT=${1:?'Missing logging output root directory'}
if [[ ! -d "$LOG_DIR_ROOT" ]] ; then
	echo "[ERROR] Invalid logging output root directory: $LOG_DIR_ROOT"
	exit 1
fi

source "$CWD/envs/env.sh"

rm -fr "$CWD/dat/ior"

declare -A max_read
declare -A max_write
declare -A is_file_path_initialized
for filepath in $(find "$LOG_DIR_ROOT" -type f -name "ior*.log") ; do
	echo "Processing $filepath"

	daos_oclass=$(awk -F/ '{ print $(NF-1) }' <<< "$filepath")
	daos_replication=${replication_method[$daos_oclass]}
	daos_dir_oclass=$(awk -F/ '{ print $(NF-2) }' <<< "$filepath")
	daos_rd_fac=$(awk -F/ '{ print $(NF-3) }' <<< "$filepath")
	ior_file_sharing=$(awk -F/ '{ print $(NF-4) }' <<< "$filepath")
	ior_mode=$(awk -F/ '{ print $(NF-5) }' <<< "$filepath")

	filename=$(basename $filepath .log)
	# nsvr=$(cut -d_ -f3 <<< $filename | cut -d- -f2)
	# nclt=$(cut -d_ -f3 <<< $filename | cut -d- -f3)
	ppn=$(cut -d_ -f4 <<< $filename)

	read_bw=$(awk 'f;/^Summary of all tests:$/{f=1}' < $filepath | grep -E -e '^read' | sed -E -e  's/[[:space:]]+/ /g' | cut -d" " -f2)
	write_bw=$(awk 'f;/^Summary of all tests:$/{f=1}' < $filepath | grep -E -e '^write' | sed -E -e  's/[[:space:]]+/ /g' | cut -d" " -f2)

	# dat_dir="$CWD/dat/ior/$ior_mode/$ior_file_sharing/$daos_rd_fac"
	dat_dir="$CWD/dat/ior"
	mkdir -p "$dat_dir"
	# dat_file="$dat_dir/ior-$daos_dir_oclass-$daos_oclass-${nsvr}-${nclt}.dat"
	dat_file="$dat_dir/ior-$ior_mode-$ior_file_sharing-$daos_rd_fac-$daos_replication-$daos_dir_oclass-$daos_oclass.dat"
	if [[ ${is_file_path_initialized[$dat_file]} != true ]] ; then
		> "$dat_file"
		is_file_path_initialized[$dat_file]=true
	fi
	echo "$ppn;$read_bw;$write_bw" >> "$dat_file"

	key="$ior_mode:$ior_file_sharing:$daos_replication"
	if [[ -z "${max_read[$key]}" ]] ; then
		max_read[$key]="0:nil:nil"
		max_write[$key]="0:nil:nil"
	fi
	max=$(cut -d: -f 1 <<< ${max_read[$key]})
	if (( $(bc -l <<< "$max < $read_bw") )) ; then
		max_read[$key]=$read_bw:$daos_dir_oclass:$daos_oclass
	fi
	max=$(cut -d: -f 1 <<< ${max_write[$key]})
	if (( $(bc -l <<< "$max < $write_bw") )) ; then
		max_write[$key]=$write_bw:$daos_dir_oclass:$daos_oclass
	fi
done

for filepath in $(find $CWD/dat/ior -type f -name "*.dat") ; do
	echo -e "Sorting dat file $filepath"

	sort -n < "$filepath" > "$filepath.new"
	echo "# ppn read(MiB) write(MiB)" > "$filepath"
	cat "$filepath.new" >> "$filepath"
	rm "$filepath.new"
done

mkdir -p "$CWD/gpi/ior" "$CWD/png/ior"

index=2
for operation in read write ; do
	for mode in easy hard ; do
		for file_sharing in shared single ; do
			for daos_replication in no_replication erasure_code replication ; do
				if [[ $daos_replication == no_replication ]] ; then
					rd_fac=rd_fac0
				else
					rd_fac=rd_fac2
				fi

				gpi_file="$CWD/gpi/ior/ior-$mode-$file_sharing-$rd_fac-$daos_replication-$operation.gpi"
				png_file="$CWD/png/ior/ior-$mode-$file_sharing-$rd_fac-$daos_replication-$operation.png"
				echo "Creating gpi file $(basename $gpi_file)"
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
				set output "$png_file"
				plot \\
				EOF
				for filepath in $(find $CWD/dat/ior -type f -name "ior-$mode-$file_sharing-$rd_fac-$daos_replication-*.dat") ; do
					filename=$(basename $filepath .dat)
					dir_oclass=$(cut -d- -f6 <<< $filename)
					oclass=$(cut -d- -f7 <<< $filename)
					cat >> $gpi_file <<- EOF
					'$filepath' using 1:$index with lines axes x1y1 title 'dir_oclass=$dir_oclass, oclass=$oclass', \\
					EOF
				done

				echo "Creating png file $(basename $png_file)"
				gnuplot -p "$gpi_file"
			done
		done
	done
	((++index))
done

echo
echo
echo "#### STATS ####"
echo
echo "# Read"
{
	echo "mode:file sharing:replication:bandwidth:dir_oclass:oclass"
	for key in ${!max_read[*]} ; do
		echo "$key:${max_read[$key]}"
	done
} | column -s ':' -t | (sed -u 1q; sort)
echo
echo "# Write"
{
	echo "mode:file sharing:replication:bandwidth:dir_oclass:oclass"
	for key in ${!max_write[*]} ; do
		echo "$key:${max_write[$key]}"
	done
} | column -s ':' -t | (sed -u 1q; sort)
echo

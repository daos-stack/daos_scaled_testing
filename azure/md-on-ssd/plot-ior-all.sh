#!/bin/bash

# set -x
set -e -o pipefail
WD=$(dirname "$(realpath "$(dirname "$0")")")
cd "$WD"

LOG_DIR_ROOT=${1:?'Missing logging output root directory'}
if [[ ! -d "$LOG_DIR_ROOT" ]] ; then
	echo "[ERROR] Invalid logging output root directory: $LOG_DIR_ROOT"
	exit 1
fi

source "$WD/envs/env.sh"

declare -A DAOS_RD_FAC=(
[no_redundancy]=0
[replication]=2
[erasure_code]=2
)
declare -A DAOS_DIR_OCLASS=(
[no_redundancy]=S1
[replication]=RP_3G1
[erasure_code]=RP_3G1
)
declare -A DAOS_OCLASS=(
[no_redundancy]=SX
[replication]=RP_3GX
[erasure_code]=EC_8P2GX
)

dat_dir="$WD/dat/md-on-ssd/ior-all"
rm -frv "$dat_dir"
mkdir -p "$dat_dir"

declare -A max_bw
declare -A is_file_path_initialized
for filepath in $(find "$LOG_DIR_ROOT" \( -type d -name "bkp" -prune \) -o \( -type f -name "ior*.log" -print \)) ; do
	echo "Processing $filepath"

	daos_bdev_cfg=$(awk -F/ '{ print $(NF-1) }' <<< "$filepath")
	daos_oclass=$(awk -F/ '{ print $(NF-2) }' <<< "$filepath")
	daos_redundancy=${redundancy_mode[$daos_oclass]}
	daos_dir_oclass=$(awk -F/ '{ print $(NF-3) }' <<< "$filepath")
	daos_rd_fac=$(awk -F/ '{ print $(NF-4) }' <<< "$filepath")
	ior_file_sharing=$(awk -F/ '{ print $(NF-5) }' <<< "$filepath")
	ior_mode=$(awk -F/ '{ print $(NF-6) }' <<< "$filepath")

	filename=$(basename $filepath .log)
	ppn=$(cut -d_ -f4 <<< $filename)

	read_bw=$(awk 'f;/^Summary of all tests:$/{f=1}' < $filepath | grep -E -e '^read' | sed -E -e  's/[[:space:]]+/ /g' | cut -d" " -f2)
	write_bw=$(awk 'f;/^Summary of all tests:$/{f=1}' < $filepath | grep -E -e '^write' | sed -E -e  's/[[:space:]]+/ /g' | cut -d" " -f2)

	dat_file="$dat_dir/ior-$ior_mode-$ior_file_sharing-$daos_rd_fac-$daos_redundancy-$daos_dir_oclass-$daos_oclass-$daos_bdev_cfg.dat"
	if [[ ${is_file_path_initialized[$dat_file]} != true ]] ; then
		> "$dat_file"
		is_file_path_initialized[$dat_file]=true
	fi
	echo "$ppn;$read_bw;$write_bw" >> "$dat_file"

	subkey="$ior_mode:$daos_redundancy:$ior_file_sharing:$daos_bdev_cfg"
	for ior_operation in read write ; do
		key="$ior_operation:$subkey"
		if [[ -z "${max_bw["$key"]}" ]] ; then
			max_bw["$key"]="0"
		fi
		[[ "$ior_operation" == read ]] && bw=$read_bw || bw=$write_bw
		if (( $(bc -l <<< "${max_bw[$key]} < $bw") )) ; then
			max_bw[$key]=$bw
		fi
	done
done

for filepath in $(find $WD/dat/md-on-ssd/ior-all -type f -name "*.dat") ; do
	echo -e "Sorting dat file $filepath"

	sort -n < "$filepath" > "$filepath.new"
	echo "# ppn read(MiB) write(MiB)" > "$filepath"
	cat "$filepath.new" >> "$filepath"
	rm "$filepath.new"
done

gpi_dir="$WD/gpi/md-on-ssd/ior-all"
png_dir="$WD/png/md-on-ssd/ior-all"
for dir in $gpi_dir $png_dir ; do
	rm -frv "$dir"
	mkdir -p "$dir"
done

index=2
for ior_operation in read write ; do
	for ior_mode in easy hard ; do
		for ior_file_sharing in single shared ; do
			for daos_redundancy in no_redundancy erasure_code replication ; do
				daos_rd_fac=${DAOS_RD_FAC[$daos_redundancy]}
				daos_dir_oclass=${DAOS_DIR_OCLASS[$daos_redundancy]}
				daos_oclass=${DAOS_OCLASS[$daos_redundancy]}

				gpi_file="$gpi_dir/ior-$ior_operation-$ior_mode-$ior_file_sharing-rd_fac$daos_rd_fac-$daos_redundancy-$daos_dir_oclass-$daos_oclass.gpi"
				png_file="$png_dir/ior-$ior_operation-$ior_mode-$ior_file_sharing-rd_fac$daos_rd_fac-$daos_redundancy-$daos_dir_oclass-$daos_oclass.png"
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
				set key right bottom

				set xlabel "Processes Number"
				set ylabel "Bandwitdh (MiB/s)"

				set term png transparent interlace lw 2 giant size 1280,1024
				set title "IOR: mode=$ior_mode io_op=$ior_operation redundancy=$daos_redundancy file_sharing=$ior_file_sharing
				set output "$png_file"
				plot \\
				EOF
				for filepath in $(find "$dat_dir" -type f -name "ior-$ior_mode-$ior_file_sharing-rd_fac$daos_rd_fac-$daos_redundancy-$daos_dir_oclass-$daos_oclass-*.dat") ; do
					filename=$(basename $filepath .dat)
					daos_bdev_cfg=$(cut -d- -f8 <<< $filename)
					cat >> $gpi_file <<- EOF
					'$filepath' using 1:$index with lines axes x1y1 title 'bdev_cfg=$daos_bdev_cfg', \\
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
echo
echo "#### STATS ####"
for ior_mode in easy hard ; do
	echo
	echo
	echo "# IOR Mode: $ior_mode"
	echo
	{
		echo "IO Operation:Redundancy Algo:File Sharing:MD on SSD BW:RAMfs BW:Percentage BW"
		for ior_operation in read write ; do
			for daos_redundancy in no_redundancy replication erasure_code ; do
				for ior_file_sharing in single shared ; do
					subkey="$ior_operation:$ior_mode:$daos_redundancy:$ior_file_sharing"
					echo -n "$ior_operation:$daos_redundancy:$ior_file_sharing"
					bw_md_on_ssd=${max_bw["$subkey:multi_bdevs"]}
					echo -n ":$(numfmt --from=iec-i --to=iec-i --format="%.2f" "${bw_md_on_ssd}Mi")B/s"
					bw_ramfs=${max_bw["$subkey:single_bdev"]}
					echo -n ":$(numfmt --from=iec-i --to=iec-i --format="%.2f" "${bw_ramfs}Mi")B/s"
					bw_percent=$(bc -l <<< "perc=(($bw_md_on_ssd * 100) / $bw_ramfs) + 0.005 ; scale=2; perc/1")
					echo ":${bw_percent}%"
				done
			done
		done
	} | column -s ':' -t
done

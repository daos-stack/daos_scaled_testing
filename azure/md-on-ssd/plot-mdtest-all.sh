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
[no_redundancy]=SX
[replication]=RP_3GX
[erasure_code]=RP_3GX
)
declare -A DAOS_OCLASS=(
[no_redundancy]=S1
[replication]=RP_3G1
[erasure_code]=EC_8P2G1
)

dat_dir="$WD/dat/md-on-ssd/mdtest-all"
rm -frv "$dat_dir"
mkdir -p "$dat_dir"

declare -A max_iops
declare -A is_file_path_initialized
for filepath in $(find "$LOG_DIR_ROOT" \( -type d -name "bkp" -prune \) -o \( -type f -name "mdtest*.log" -print \)) ; do
	echo "Processing $filepath"

	daos_bdev_cfg=$(basename $(dirname $filepath))
	daos_oclass=$(basename $(dirname $(dirname $filepath)))
	daos_redundancy=${redundancy_mode[$daos_oclass]}
	daos_dir_oclass=$(basename $(dirname $(dirname $(dirname $filepath))))
	daos_rd_fac=$(basename $(dirname $(dirname $(dirname $(dirname $filepath)))))
	mdtest_mode=$(basename $(dirname $(dirname $(dirname $(dirname $(dirname $filepath))))))

	filename=$(basename $filepath .log)
	ppn=$(cut -d- -f3 <<< $filename | cut -d_ -f2)

	file_creation=$(awk '/^SUMMARY rate:.*$/{f=1;next};/^SUMMARY time:.*$/{f=0;next};f' < $filepath | grep -E -e 'File creation' | sed -E -e  's/^[[:space:]]+//' -e  's/[[:space:]]+/;/g' | cut -d\; -f5)
	file_stat=$(awk '/^SUMMARY rate:.*$/{f=1;next};/^SUMMARY time:.*$/{f=0;next};f' < $filepath | grep -E -e 'File stat' | sed -E -e  's/^[[:space:]]+//' -e  's/[[:space:]]+/;/g' | cut -d\; -f5)
	file_removal=$(awk '/^SUMMARY rate:.*$/{f=1;next};/^SUMMARY time:.*$/{f=0;next};f' < $filepath | grep -E -e 'File removal' | sed -E -e  's/^[[:space:]]+//' -e  's/[[:space:]]+/;/g' | cut -d\; -f5)

	daos_file="$dat_dir/mdtest-$mdtest_mode-$daos_rd_fac-$daos_redundancy-$daos_dir_oclass-$daos_oclass-$daos_bdev_cfg.dat"
	if [[ ${is_file_path_initialized[$daos_file]} != true ]] ; then
		> "$daos_file"
		is_file_path_initialized[$daos_file]=true
	fi
	echo "$ppn;$file_creation;$file_stat;$file_removal" >> "$daos_file"

	subkey="$mdtest_mode:$daos_redundancy:$daos_bdev_cfg"
	for mdtest_operation in create stat remove ; do
		key="$mdtest_operation:$subkey"
		if [[ -z "${max_iops[$key]}" ]] ; then
			max_iops[$key]=0
		fi
		case "$mdtest_operation" in
			create) iops=$file_creation ;;
			stat) iops=$file_stat ;;
			remove) iops=$file_removal ;;
		esac
		if (( $(bc -l <<< "${max_iops[$key]} < $iops") )) ; then
			max_iops[$key]=$iops
		fi
	done
done

for filepath in $(find $WD/dat/md-on-ssd/mdtest-all -type f -name "*.dat") ; do
	echo -e "Sorting dat file $filepath"

	sort -n < "$filepath" > "$filepath.new"
	echo "# ppn creation(iops) stat(iops) removal(iops)" > "$filepath"
	cat "$filepath.new" >> "$filepath"
	rm "$filepath.new"
done

gpi_dir="$WD/gpi/md-on-ssd/mdtest-all"
png_dir="$WD/png/md-on-ssd/mdtest-all"
for dir in $gpi_dir $png_dir ; do
	rm -frv "$dir"
	mkdir -p "$dir"
done

index=2
for mdtest_operation in creation stat removal ; do
	for mdtest_mode in easy hard ; do
		for daos_redundancy in no_redundancy erasure_code replication ; do
			daos_rd_fac=${DAOS_RD_FAC[$daos_redundancy]}
			gpi_file="$gpi_dir/mdtest-$mdtest_mode-rd_fac$daos_rd_fac-$daos_redundancy-$mdtest_operation.gpi"
			png_file="$png_dir/mdtest-$mdtest_mode-rd_fac$daos_rd_fac-$daos_redundancy-$mdtest_operation.png"
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

			set xlabel "Processes number per node"
			set ylabel "iops"

			set term png transparent interlace lw 2 giant size 1280,1024

			set title "MDTEST: mode=$mdtest_mode operation=$mdtest_operation redundancy=$daos_redundancy"
			set output "$png_file"
			plot \\
			EOF
			for filepath in $(find $dat_dir -type f -name "mdtest-$mdtest_mode-rd_fac$daos_rd_fac-$daos_redundancy-*.dat") ; do
				filename=$(basename $filepath .dat)
				daos_bdev_cfg=$(cut -d- -f7 <<< $filename)
				cat >> $gpi_file <<- EOF
				'$filepath' using 1:$index with lines axes x1y1 title 'bdev_cfg=$daos_bdev_cfg', \\
				EOF
			done

			echo "Creating png file $(basename $png_file)"
			gnuplot -p "$gpi_file"
		done
	done
	((++index))
done

echo
echo
echo
echo "#### STATS ####"
for mdtest_mode in easy hard ; do
	echo
	echo
	echo "# MDTEST Mode: $mdtest_mode"
	echo
	{
		echo "Operation:Redundancy Algo:MD on SSD IOPS:RAMfs IOPS:Percentage IOPS"
		for mdtest_operation in create stat remove ; do
			for daos_redundancy in no_redundancy replication erasure_code ; do
				subkey="$mdtest_operation:$mdtest_mode:$daos_redundancy"
				echo -n "$mdtest_operation:$daos_redundancy"
				iops_md_on_ssd=${max_iops["$subkey:multi_bdevs"]}
				echo -n ":$(bc -l <<< "iops=($iops_md_on_ssd / 1000) + .005; scale=2; iops/1")Kiops"
				iops_ramfs=${max_iops["$subkey:single_bdev"]}
				echo -n ":$(bc -l <<< "iops=($iops_ramfs / 1000) + .005; scale=2; iops/1")Kiops"
				iops_percent=$(bc -l <<< "perc=(($iops_md_on_ssd * 100) / $iops_ramfs) + .005; scale=2; perc/1")
				echo ":${iops_percent}%"
			done
		done
	} | column -s ':' -t
done

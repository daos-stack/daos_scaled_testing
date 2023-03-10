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

rm -fr "$CWD/dat/mdtest"

declare -A max_create_iops
declare -A max_stat_iops
declare -A max_remove_iops
declare -A is_file_path_initialized
for filepath in $(find "$LOG_DIR_ROOT" -type f -name "mdtest*.log") ; do
	echo "Processing $filepath"

	oclass=$(basename $(dirname $filepath))
	replication_method=${replication_method[$oclass]}
	dir_oclass=$(basename $(dirname $(dirname $filepath)))
	rf=$(basename $(dirname $(dirname $(dirname $filepath))))
	test_type=$(basename $(dirname $(dirname $(dirname $(dirname $filepath)))))

	filename=$(basename $filepath .log)
	# nsvr=$(cut -d- -f2 <<< $filename)
	# nclt=$(cut -d- -f3 <<< $filename | cut -d_ -f1)
	ppn=$(cut -d- -f3 <<< $filename | cut -d_ -f2)
	# np=$(( $ppn * $nclt ))

	file_creation=$(awk '/^SUMMARY rate:.*$/{f=1;next};/^SUMMARY time:.*$/{f=0;next};f' < $filepath | grep -E -e 'File creation' | sed -E -e  's/^[[:space:]]+//' -e  's/[[:space:]]+/;/g' | cut -d\; -f5)
	file_stat=$(awk '/^SUMMARY rate:.*$/{f=1;next};/^SUMMARY time:.*$/{f=0;next};f' < $filepath | grep -E -e 'File stat' | sed -E -e  's/^[[:space:]]+//' -e  's/[[:space:]]+/;/g' | cut -d\; -f5)
	file_removal=$(awk '/^SUMMARY rate:.*$/{f=1;next};/^SUMMARY time:.*$/{f=0;next};f' < $filepath | grep -E -e 'File removal' | sed -E -e  's/^[[:space:]]+//' -e  's/[[:space:]]+/;/g' | cut -d\; -f5)

	od="$CWD/dat/mdtest/"
	mkdir -p "$od"
	of="$od/mdtest-$test_type-$rf-$replication_method-$dir_oclass-$oclass.dat"
	if [[ ${is_file_path_initialized[$of]} != true ]] ; then
		> "$of"
		is_file_path_initialized[$of]=true
	fi
	echo "$ppn;$file_creation;$file_stat;$file_removal" >> "$of"

	key="$test_type:$replication_method"
	if [[ -z ${max_create_iops[$key]} ]] ; then
		max_create_iops[$key]="0:nil:nil"
		max_stat_iops[$key]="0:nil:nil"
		max_remove_iops[$key]="0:nil:nil"
	fi
	max=$(cut -d: -f 1 <<< ${max_create_iops[$key]})
	if (( $(bc -l <<< "$max < $file_creation") )) ; then
		max_create_iops[$key]="$file_creation:$dir_oclass:$oclass"
	fi
	max=$(cut -d: -f 1 <<< ${max_stat_iops[$key]})
	if (( $(bc -l <<< "$max < $file_stat") )) ; then
		max_stat_iops[$key]="$file_stat:$dir_oclass:$oclass"
	fi
	max=$(cut -d: -f 1 <<< ${max_remove_iops[$key]})
	if (( $(bc -l <<< "$max < $file_removal") )) ; then
		max_remove_iops[$key]="$file_removal:$dir_oclass:$oclass"
	fi
done

mkdir -p "$CWD/dat/mdtest"
for filepath in $(find $CWD/dat/mdtest/ -type f -name "*.dat") ; do
	echo -e "Sorting dat file $filepath"

	sort -n < "$filepath" > "$filepath.new"
	echo "# ppn creation(iops) stat(iops) removal(iops)" > "$filepath"
	cat "$filepath.new" >> "$filepath"
	rm "$filepath.new"
done

mkdir -p "$CWD/gpi/mdtest" "$CWD/png/mdtest"

index=2
for operation in creation stat removal ; do
	for mode in easy hard ; do
		for replication_method in no_replication erasure_code replication ; do
			if [[ $replication_method == no_replication ]] ; then
				rd_fac=rd_fac0
			else
				rd_fac=rd_fac2
			fi
			gpi_file="$CWD/gpi/mdtest/mdtest-$mode-$rd_fac-$replication_method-$operation.gpi"
			png_file="$CWD/png/mdtest/mdtest-$mode-$rd_fac-$replication_method-$operation.png"
			echo "Creating png file $(basename $png_file)"

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

			set title "MDTEST: operation=$operation mode=$mode replication_method=$replication_method redundancy_factor=$rd_fac"
			set output "$png_file"
			plot \\
			EOF
			for filepath in $(find $CWD/dat/mdtest -type f -name "mdtest-$mode-$rd_fac-$replication_method-*.dat") ; do
				filename=$(basename $filepath .dat)
				dir_oclass=$(cut -d- -f5 <<< $filename)
				oclass=$(cut -d- -f6 <<< $filename)
				cat >> $gpi_file <<- EOF
				'$filepath' using 1:$index with lines axes x1y1 title 'dir_oclass=$dir_oclass, oclass=$oclass', \\
				EOF
			done
			gnuplot -p "$gpi_file"
		done
	done
	((++index))
done

echo
echo
echo "#### STATS ####"
echo
echo "# File Creation"
{
	echo "mode:replication:create iops:dir_oclass:oclass"
	for key in ${!max_create_iops[*]} ; do
		echo "$key:${max_create_iops[$key]}"
	done
} | column -s ':' -t | (sed -u 1q; sort)
echo
echo "# File Stat"
{
	echo "mode:replication:create iops:dir_oclass:oclass"
	for key in ${!max_stat_iops[*]} ; do
		echo "$key:${max_stat_iops[$key]}"
	done
} | column -s ':' -t | (sed -u 1q; sort)
echo
echo "# File Removal"
{
	echo "mode:replication:create iops:dir_oclass:oclass"
	for key in ${!max_remove_iops[*]} ; do
		echo "$key:${max_remove_iops[$key]}"
	done
} | column -s ':' -t | (sed -u 1q; sort)

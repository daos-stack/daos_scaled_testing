#!/bin/bash

# set -x
set -e -o pipefail
CWD="$(realpath "$(dirname $0)")"

GIGA_IBYTE=$(( 1 << 30 ))

LOG_DIR_ROOT=${1:?'Missing logging output root directory'}
if [[ ! -d "$LOG_DIR_ROOT" ]] ; then
	echo "[ERROR] Invalid logging output root directory: $LOG_DIR_ROOT"
	exit 1
fi

for dirname in dat gpi png ; do
	mkdir -p "$CWD/$dirname/fio-iodepth" "$CWD/$dirname/fio-clients_nb"
done

GNUPLOT_TITLE=${2:?'Missing gnuplot title'}

GNUPLOT_YRANGE=${3-}


# Processing results file

declare -A max_iops=( [daos-read]=0 [daos-seqread]=0 [daos-randread]=0 [daos-write]=0 [daos-seqwrite]=0 [daos-randwrite]=0 )
declare -A is_file_path_initialized
for filepath in $(find "$LOG_DIR_ROOT" -type f -name "fio*.json") ; do
	echo "Processing $filepath"

	filename=$(basename "$filepath" .json)
	fio_mode=$(cut -d- -f2 <<< $filename)
	fio_iodepth=$(cut -d- -f3 <<< $filename)
	daos_rd_fac=$(cut -d- -f4 <<< $filename)
	daos_oclass=$(cut -d- -f5 <<< $filename)
	servers_nb=$(cut -d- -f6 <<< $filename)
	clients_nb=$(cut -d- -f7 <<< $filename)

	daos_randread_iops=$(sed -E -e '1,/^$/d' "$filepath" | jq -r '[.client_stats[] | select(.jobname=="daos-randread") |.read.iops ] | add')
	daos_seqread_iops=$(sed -E -e '1,/^$/d' "$filepath" | jq -r '[.client_stats[] | select(.jobname=="daos-seqread") |.read.iops ] | add')
	if (( $(bc -l <<< "$daos_randread_iops < $daos_seqread_iops") )) ; then
		daos_read_iops=$daos_seqread_iops
	else
		daos_read_iops=$daos_randread_iops
	fi

	daos_randwrite_iops=$(sed -E -e '1,/^$/d' "$filepath" | jq -r '[.client_stats[] | select(.jobname=="daos-randwrite") |.write.iops ] | add')
	daos_seqwrite_iops=$(sed -E -e '1,/^$/d' "$filepath" | jq -r '[.client_stats[] | select(.jobname=="daos-seqwrite") |.write.iops ] | add')
	if (( $(bc -l <<< "$daos_randwrite_iops < $daos_seqwrite_iops") )) ; then
		daos_write_iops=$daos_seqwrite_iops
	else
		daos_write_iops=$daos_randwrite_iops
	fi

	if (( $(bc -l <<< "$(cut -d: -f 1 <<< ${max_iops[daos-read]}) < $daos_read_iops") )) ; then
		max_iops[daos-read]=$daos_read_iops:$fio_iodepth:$clients_nb
	fi
	if (( $(bc -l <<< "$(cut -d: -f 1 <<< ${max_iops[daos-seqread]}) < $daos_seqread_iops") )) ; then
		max_iops[daos-seqread]=$daos_seqread_iops:$fio_iodepth:$clients_nb
	fi
	if (( $(bc -l <<< "$(cut -d: -f 1 <<< ${max_iops[daos-randread]}) < $daos_randread_iops") )) ; then
		max_iops[daos-randread]=$daos_randread_iops:$fio_iodepth:$clients_nb
	fi

	if (( $(bc -l <<< "$(cut -d: -f 1 <<< ${max_iops[daos-write]}) < $daos_write_iops") )) ; then
		max_iops[daos-write]=$daos_write_iops:$fio_iodepth:$clients_nb
	fi
	if (( $(bc -l <<< "$(cut -d: -f 1 <<< ${max_iops[daos-seqwrite]}) < $daos_seqwrite_iops") )) ; then
		max_iops[daos-seqwrite]=$daos_seqwrite_iops:$fio_iodepth:$clients_nb
	fi
	if (( $(bc -l <<< "$(cut -d: -f 1 <<< ${max_iops[daos-randwrite]}) < $daos_randwrite_iops") )) ; then
		max_iops[daos-randwrite]=$daos_randwrite_iops:$fio_iodepth:$clients_nb
	fi

	of="$CWD/dat/fio-clients_nb/fio-clients_nb-$fio_mode-$fio_iodepth-$daos_rd_fac-$daos_oclass-$servers_nb.dat"
	if [[ ${is_file_path_initialized[$of]} != true ]] ; then
		echo "Creating outputfile $CWD/dat/fio-clients_nb/fio-clients_nb-$fio_mode-$fio_iodepth-$daos_rd_fac-$daos_oclass-$servers_nb.dat"
		> "$of"
		is_file_path_initialized[$of]=true
	fi
	echo "$clients_nb;$daos_seqread_iops;$daos_randread_iops;$daos_seqwrite_iops;$daos_randwrite_iops" >> $of
done

echo -e "Sorting dat files"
for filepath in ${!is_file_path_initialized[@]} ; do
	sort -n < "$filepath" > "$filepath.new"
	cat "$filepath.new" > "$filepath"
	rm "$filepath.new"
done


# Generating FIO client number graph files

if [[ ${#is_file_path_initialized[@]} -gt 1 ]] ; then
	echo "Only one dat file is currently supported"
	exit 1
fi
if [[ $GNUPLOT_YRANGE ]] ; then
	GNUPLOT_SCALE=$(cat <<- EOF
		set autoscale x
		set yrange $GNUPLOT_YRANGE
		EOF
	)
else
	GNUPLOT_SCALE="set autoscale xy"
fi
echo "Generaring FIO client number graph files"
file_path="${!is_file_path_initialized[@]}"
gpi_file="$CWD/gpi/fio-clients_nb/fio-clients_nb.gpi"
png_file="$CWD/png/fio-clients_nb/fio-clients_nb.png"
cat > "$gpi_file" << EOF
set border 11
set xtics nomirror
set ytics nomirror
set y2tics nomirror
set grid xtics ytics
$GNUPLOT_SCALE
set encoding iso_8859_1
set datafile separator ";"

set xlabel "FIO client D32s v4"
set ylabel "IOPS"

set term png transparent interlace lw 2 giant size 1280,1024

set title "$GNUPLOT_TITLE"
set output "$png_file"
plot \\
EOF

index=2
for fio_mode in seqread randread seqwrite randwrite ; do
	cat >> $gpi_file <<- EOF
	'$filepath' using 1:$index with lines axes x1y1 title 'fio-mode=$fio_mode', \\
	EOF
	((++index))
done

gnuplot -p "$gpi_file"


# Print stat info

echo
echo "IOPS Statistic:"
for jobname in daos-read daos-randread daos-seqread daos-write daos-randwrite daos-seqwrite ; do
	echo -e "\t- Max IOPS for $jobname: iops=$(cut -d: -f1 <<< ${max_iops[$jobname]}) iodepth=$(cut -d: -f2 <<< ${max_iops[$jobname]}) clients_nb=$(cut -d: -f3 <<< ${max_iops[$jobname]})"
done

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
	rm -fr "$CWD/$dirname/fio-servers_nb"
	mkdir -p "$CWD/$dirname/fio-servers_nb"
done


# Processing results file

declare -A max_iops=( [daos-read]=0 [daos-read_client1]=0 [daos-seqread]=0 [daos-randread]=0 [daos-write]=0 [daos-write_client1]=0 [daos-seqwrite]=0 [daos-randwrite]=0 )
declare -A max_bw=( [daos-read]=0 [daos-seqread]=0 [daos-randread]=0 [daos-write]=0 [daos-seqwrite]=0 [daos-randwrite]=0 )
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

	daos_randread_bw=$(sed -E -e '1,/^$/d' "$filepath" | jq -r '[.client_stats[] | select(.jobname=="daos-randread") |.read.bw_bytes ] | add')
	daos_seqread_bw=$(sed -E -e '1,/^$/d' "$filepath" | jq -r '[.client_stats[] | select(.jobname=="daos-seqread") |.read.bw_bytes ] | add')
	if (( $(bc -l <<< "$daos_randread_bw < $daos_seqread_bw") )) ; then
		daos_read_bw=$daos_seqread_bw
	else
		daos_read_bw=$daos_randread_bw
	fi

	daos_randwrite_bw=$(sed -E -e '1,/^$/d' "$filepath" | jq -r '[.client_stats[] | select(.jobname=="daos-randwrite") |.write.bw_bytes ] | add')
	daos_seqwrite_bw=$(sed -E -e '1,/^$/d' "$filepath" | jq -r '[.client_stats[] | select(.jobname=="daos-seqwrite") |.write.bw_bytes ] | add')
	if (( $(bc -l <<< "$daos_randwrite_bw < $daos_seqwrite_bw") )) ; then
		daos_write_bw=$daos_seqwrite_bw
	else
		daos_write_bw=$daos_randwrite_bw
	fi

	if  (( $(bc -l <<< "$(cut -d: -f 1 <<< ${max_iops[daos-read]}) < $daos_read_iops") )) ; then
		max_iops[daos-read]=$daos_read_iops:$servers_nb:$clients_nb
	fi
	if  [[ $clients_nb -eq 1 ]] && (( $(bc -l <<< "$(cut -d: -f 1 <<< ${max_iops[daos-read_client1]}) < $daos_read_iops") )) ; then
		max_iops[daos-read_client1]=$daos_read_iops:$servers_nb:$clients_nb
	fi
	if (( $(bc -l <<< "$(cut -d: -f 1 <<< ${max_iops[daos-seqread]}) < $daos_seqread_iops") )) ; then
	    max_iops[daos-seqread]=$daos_seqread_iops:$servers_nb:$clients_nb
	fi
	if (( $(bc -l <<< "$(cut -d: -f 1 <<< ${max_iops[daos-randread]}) < $daos_randread_iops") )) ; then
	    max_iops[daos-randread]=$daos_randread_iops:$servers_nb:$clients_nb
	fi

	if (( $(bc -l <<< "$(cut -d: -f 1 <<< ${max_iops[daos-write]}) < $daos_write_iops") )) ; then
	    max_iops[daos-write]=$daos_write_iops:$servers_nb:$clients_nb
	fi
	if [[ $clients_nb -eq 1 ]] && (( $(bc -l <<< "$(cut -d: -f 1 <<< ${max_iops[daos-write_client1]}) < $daos_write_iops") )) ; then
	    max_iops[daos-write_client1]=$daos_write_iops:$servers_nb:$clients_nb
	fi
	if (( $(bc -l <<< "$(cut -d: -f 1 <<< ${max_iops[daos-seqwrite]}) < $daos_seqwrite_iops") )) ; then
	    max_iops[daos-seqwrite]=$daos_seqwrite_iops:$servers_nb:$clients_nb
	fi
	if (( $(bc -l <<< "$(cut -d: -f 1 <<< ${max_iops[daos-randwrite]}) < $daos_randwrite_iops") )) ; then
		max_iops[daos-randwrite]=$daos_randwrite_iops:$servers_nb:$clients_nb
	fi

	if  (( $(bc -l <<< "$(cut -d: -f 1 <<< ${max_bw[daos-read]}) < $daos_read_bw") )) ; then
		max_bw[daos-read]=$daos_read_bw:$servers_nb:$clients_nb
	fi
	if (( $(bc -l <<< "$(cut -d: -f 1 <<< ${max_bw[daos-seqread]}) < $daos_seqread_bw") )) ; then
	    max_bw[daos-seqread]=$daos_seqread_bw:$servers_nb:$clients_nb
	fi
	if (( $(bc -l <<< "$(cut -d: -f 1 <<< ${max_bw[daos-randread]}) < $daos_randread_bw") )) ; then
	    max_bw[daos-randread]=$daos_randread_bw:$servers_nb:$clients_nb
	fi

	if (( $(bc -l <<< "$(cut -d: -f 1 <<< ${max_bw[daos-write]}) < $daos_write_bw") )) ; then
	    max_bw[daos-write]=$daos_write_bw:$servers_nb:$clients_nb
	fi
	if (( $(bc -l <<< "$(cut -d: -f 1 <<< ${max_bw[daos-seqwrite]}) < $daos_seqwrite_bw") )) ; then
	    max_bw[daos-seqwrite]=$daos_seqwrite_bw:$servers_nb:$clients_nb
	fi
	if (( $(bc -l <<< "$(cut -d: -f 1 <<< ${max_bw[daos-randwrite]}) < $daos_randwrite_bw") )) ; then
		max_bw[daos-randwrite]=$daos_randwrite_bw:$servers_nb:$clients_nb
	fi

	of="$CWD/dat/fio-servers_nb/fio-servers_nb-$fio_mode-$fio_iodepth-$daos_rd_fac-$daos_oclass-$clients_nb.dat"
	if [[ ${is_file_path_initialized[$of]} != true ]] ; then
		> "$of"
		is_file_path_initialized[$of]=true
	fi
	echo "$servers_nb;$daos_seqread_iops;$daos_randread_iops;$daos_seqwrite_iops;$daos_randwrite_iops;$daos_seqread_bw;$daos_randread_bw;$daos_seqwrite_bw;$daos_randwrite_bw" >> $of
done

echo -e "Sorting dat files"
for filepath in $(find "$CWD/dat/fio-servers_nb" -type f -name "*.dat") ; do
	sort -n < "$filepath" > "$filepath.new"
	cat "$filepath.new" > "$filepath"
	rm "$filepath.new"
done


# Generating IOPS files

echo "Generaring FIO IOPS graph files"
gpi_file="$CWD/gpi/fio-servers_nb/fio-servers_nb-iops.gpi"
cat > "$gpi_file" << EOF
set border 11
set xtics nomirror
set ytics nomirror
set y2tics nomirror
set grid xtics ytics
set autoscale
set encoding iso_8859_1
set datafile separator ";"

set xlabel "Servers number"
set ylabel "IOPS"

set term png transparent interlace lw 2 giant size 1280,1024
EOF

index=2
for fio_mode in seqread randread seqwrite randwrite ; do
	png_file="$CWD/png/fio-servers_nb/fio-servers_nb-iops-$fio_mode.png"

	cat >> "$gpi_file" <<- EOF

	set title "FIO: jobname=daos-$fio_mode"
	set output "$png_file"
	plot \\
	EOF
	for filepath in $(find "$CWD/dat/fio-servers_nb" -name "*.dat") ; do
		filename=$(basename "$filepath" .dat)
		clients_nb=$(cut -d- -f7 <<< $filename)
		cat >> $gpi_file <<- EOF
		'$filepath' using 1:$index with lines axes x1y1 title 'clients_nb=$clients_nb', \\
		EOF
	done
	((++index))
done

gnuplot -p "$gpi_file"


# Generating Bandwidth files

echo "Generaring FIO Bandwidth graph files"
gpi_file="$CWD/gpi/fio-servers_nb/fio-servers_nb-bw.gpi"
cat > "$gpi_file" << EOF
set border 11
set xtics nomirror
set ytics nomirror
set y2tics nomirror
set grid xtics ytics
set autoscale
set encoding iso_8859_1
set datafile separator ";"

set xlabel "Servers number"
set ylabel "Bandwidth"

set term png transparent interlace lw 2 giant size 1280,1024
EOF

for fio_mode in seqread randread seqwrite randwrite ; do
	png_file="$CWD/png/fio-servers_nb/fio-servers_nb-bw-$fio_mode.png"

	cat >> "$gpi_file" <<- EOF

	set title "FIO: jobname=daos-$fio_mode"
	set output "$png_file"
	plot \\
	EOF
	for filepath in $(find "$CWD/dat/fio-servers_nb" -name "*.dat") ; do
		filename=$(basename "$filepath" .dat)
		clients_nb=$(cut -d- -f7 <<< $filename)
		cat >> $gpi_file <<- EOF
		'$filepath' using 1:$index with lines axes x1y1 title 'clients_nb=$clients_nb', \\
		EOF
	done
	((++index))
done

gnuplot -p "$gpi_file"


# Print stat info

echo
echo "IOPS Statistic:"
for jobname in daos-read daos-read_client1 daos-randread daos-seqread daos-write daos-write_client1 daos-randwrite daos-seqwrite ; do
	echo -e "\t- Max IOPS for $jobname: iops=$(cut -d: -f1 <<< ${max_iops[$jobname]}) servers_nb=$(cut -d: -f2 <<< ${max_iops[$jobname]}) clients_nb=$(cut -d: -f3 <<< ${max_iops[$jobname]})"
done

echo
echo "Bandwidth Statistic:"
for jobname in daos-read daos-randread daos-seqread daos-write daos-randwrite daos-seqwrite ; do
	echo -e "\t- Max Bandwidth for $jobname: bw=$(numfmt --to=iec-i <<< $(cut -d: -f1 <<< ${max_bw[$jobname]})) servers_nb=$(cut -d: -f2 <<< ${max_bw[$jobname]}) clients_nb=$(cut -d: -f3 <<< ${max_bw[$jobname]})"
done

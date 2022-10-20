#!/bin/bash

# set -x
set -e
set -o pipefail
CWD="$(realpath "$(dirname $0)")"

declare -A is_file_path_iniialized
for dirpath in "$@" ; do

	if [[ ! -d  "$dirpath" ]] ; then
		continue
	fi

	file_nb=1
	for filepath in $(find "$dirpath" -type f) ; do
		echo "Processing $filepath"

		rf=$(basename $(dirname $(dirname $(dirname $filepath))))
		filename=$(basename $filepath .log)
		test_name=$(cut -d_ -f1 <<< $filename)
		if [[ $test_name == ior ]] ; then
			test_type=$(cut -d_ -f2 <<< $filename)
			file_mode=$(cut -d_ -f3 <<< $filename | cut -d- -f1)
			oclass=$(grep -E -e "^Command line[[:space:]]*:.*$" $filepath | sed -n -E -e 's/^.*--dfs\.oclass=([^[:space:]]+)[[:space:]]*.*$/\1/p')
			mkdir -p dat/$test_name/$test_type/$file_mode/$oclass

			nsvr=$(cut -d_ -f3 <<< $filename | cut -d- -f2)
			nclt=$(cut -d_ -f3 <<< $filename | cut -d- -f3)
			ppn=$(cut -d_ -f4 <<< $filename)

			write_bw=$(awk 'f;/^Summary of all tests:$/{f=1}' < $filepath | grep -E -e '^write' | sed -E -e  's/[[:space:]]+/ /g' | cut -d" " -f2)
			read_bw=$(awk 'f;/^Summary of all tests:$/{f=1}' < $filepath | grep -E -e '^read' | sed -E -e  's/[[:space:]]+/ /g' | cut -d" " -f2)

			file_path="dat/$test_name/$test_type/$file_mode/$oclass/${nsvr}_${nclt}_$rf.dat"
			if [[ ${is_file_path_iniialized["$file_path"]} != true ]] ; then
				> "$file_path"
				is_file_path_iniialized["$file_path"]=true
			fi
			echo "$ppn;$write_bw;$read_bw" >> "$file_path"
		elif [[ $test_name == mdtest ]] ; then
			test_type=$(cut -d_ -f2 <<< $filename | cut -d- -f1)
			oclass=$(grep -E -e "^Command line used:.*$" $filepath | sed -n -E -e "s/^.*--dfs\.oclass=([^']+)'.*$/\1/p")
			mkdir -p dat/$test_name/$test_type/$oclass

			nsvr=$(cut -d- -f2 <<< $filename)
			nclt=$(cut -d- -f3 <<< $filename | cut -d_ -f1)
			ppn=$(cut -d- -f3 <<< $filename | cut -d_ -f2)

			file_creation=$(awk '/^SUMMARY rate:.*$/{f=1;next};/^SUMMARY time:.*$/{f=0;next};f' < $filepath | grep -E -e 'File creation' | sed -E -e  's/^[[:space:]]+//' -e  's/[[:space:]]+/;/g' | cut -d\; -f5)
			file_stat=$(awk '/^SUMMARY rate:.*$/{f=1;next};/^SUMMARY time:.*$/{f=0;next};f' < $filepath | grep -E -e 'File stat' | sed -E -e  's/^[[:space:]]+//' -e  's/[[:space:]]+/;/g' | cut -d\; -f5)
			file_removal=$(awk '/^SUMMARY rate:.*$/{f=1;next};/^SUMMARY time:.*$/{f=0;next};f' < $filepath | grep -E -e 'File removal' | sed -E -e  's/^[[:space:]]+//' -e  's/[[:space:]]+/;/g' | cut -d\; -f5)

			file_path="dat/$test_name/$test_type/$oclass/${nsvr}_${nclt}_$rf.dat"
			if [[ ${is_file_path_iniialized["$file_path"]} != true ]] ; then
				> "$file_path"
				is_file_path_iniialized["$file_path"]=true
			fi
			echo "$ppn;$file_creation;$file_stat;$file_removal" >> "$file_path"
		fi

		file_nb=$(( $file_nb + 1 ))
	done
done
echo

for filepath in $(find $CWD/dat -type f) ; do
	echo -e "Sorting dat file $filepath"

	sort -n < $filepath > $filepath.new

	test_name=$(cut -d_ -f1 <<< $filename)
	if [[ $filepath =~ $cwd/dat/ior/ ]] ; then
		echo "# ppn write(MiB) read(MiB)" > $filepath
	elif [[ $filepath =~ $cwd/dat/mdtest/ ]] ; then
		echo "# ppn file_creation(iops) file_stat(iops) file_removal(iops)" > $filepath
	fi
	cat $filepath.new >> $filepath
	rm $filepath.new
done
echo

for dirpath in $(find $CWD/dat/ior -type d -links 2 -exec dirname {} \; | uniq) ; do
	file_mode=$(basename $dirpath)
	test_type=$(basename $(dirname $dirpath))
	filename=ior_${test_type}_$file_mode
	echo "Generaring graph file $filename"

	file_gpi=$CWD/gpi/$filename.gpi
	file_png=$CWD/png/$filename.png

	cat > $file_gpi <<- EOF
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
	set title "IOR: type=$test_type file_mode=$file_mode"

	set output "$file_png"
	plot \\
	EOF
	for filepath in $(find "$dirpath" -name "*.dat") ; do
		oclass=$(basename $(dirname $filepath))
		cat >> $file_gpi <<- EOF
		'$filepath' using 1:2 with lines axes x1y1 title 'write-$oclass', \\
		'$filepath' using 1:3 with lines axes x1y1 title 'read-$oclass', \\
		EOF
	done

	file_png=$CWD/png/${filename}_write.png
	cat >> $file_gpi <<- EOF

	set output "$file_png"
	plot \\
	EOF
	for filepath in $(find "$dirpath" -name "*.dat") ; do
		oclass=$(basename $(dirname $filepath))
		cat >> $file_gpi <<- EOF
		'$filepath' using 1:2 with lines axes x1y1 title 'write-$oclass', \\
		EOF
	done

	file_png=$CWD/png/${filename}_read.png
	cat >> $file_gpi <<- EOF

	set output "$file_png"
	plot \\
	EOF
	for filepath in $(find "$dirpath" -name "*.dat") ; do
		oclass=$(basename $(dirname $filepath))
		cat >> $file_gpi <<- EOF
		'$filepath' using 1:3 with lines axes x1y1 title 'read-$oclass', \\
		EOF
	done

	gnuplot -p $file_gpi
done

for dirpath in $(find $CWD/dat/mdtest -type d -links 2 -exec dirname {} \; | uniq) ; do
	test_type=$(basename $dirpath)
	filename=mdtest_${test_type}
	echo "Generaring graph file $filename"

	file_gpi=$CWD/gpi/$filename.gpi
	file_png=$CWD/png/$filename.png

	cat > $file_gpi <<- EOF
	set border 11
	set xtics nomirror
	set ytics nomirror
	set y2tics nomirror
	set grid xtics ytics
	set autoscale
	set encoding iso_8859_1
	set datafile separator ";"

	set xlabel "Processes Number"
	set ylabel "IOPS"

	set term png transparent interlace lw 2 giant size 1280,1024
	set title "MDTEST: type=$test_type"

	set output "$file_png"
	plot \\
	EOF
	for filepath in $(find "$dirpath" -name "*.dat") ; do
		oclass=$(basename $(dirname $filepath))
		cat >> $file_gpi <<- EOF
		'$filepath' using 1:2 with lines axes x1y1 title 'create_$oclass', \\
		'$filepath' using 1:3 with lines axes x1y1 title 'stat_$oclass', \\
		'$filepath' using 1:4 with lines axes x1y1 title 'removal_$oclass', \\
		EOF
	done

	file_png=$CWD/png/${filename}_create.png
	cat >> $file_gpi <<- EOF

	set output "$file_png"
	plot \\
	EOF

	for filepath in $(find "$dirpath" -name "*.dat") ; do
		oclass=$(basename $(dirname $filepath))
		cat >> $file_gpi <<- EOF
		'$filepath' using 1:2 with lines axes x1y1 title 'create_$oclass', \\
		EOF
	done

	file_png=$CWD/png/${filename}_stat.png
	cat >> $file_gpi <<- EOF

	set output "$file_png"
	plot \\
	EOF

	for filepath in $(find "$dirpath" -name "*.dat") ; do
		oclass=$(basename $(dirname $filepath))
		cat >> $file_gpi <<- EOF
		'$filepath' using 1:3 with lines axes x1y1 title 'stat_$oclass', \\
		EOF
	done

	file_png=$CWD/png/${filename}_removal.png
	cat >> $file_gpi <<- EOF

	set output "$file_png"
	plot \\
	EOF

	for filepath in $(find "$dirpath" -name "*.dat") ; do
		oclass=$(basename $(dirname $filepath))
		cat >> $file_gpi <<- EOF
		'$filepath' using 1:4 with lines axes x1y1 title 'removal_$oclass', \\
		EOF
	done

	gnuplot -p $file_gpi
done

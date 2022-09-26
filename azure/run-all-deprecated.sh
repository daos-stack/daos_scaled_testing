#!/bin/bash

# set -x
set -e
set -o pipefail

CWD="$(realpath "$(dirname $0)")"

for mode in easy hard ; do
	for file_opt in single shared ; do
		if [[ $mode == easy && $file_opt == single ]] ; then
			continue
		fi
		for rd_fct in {0..2} ; do
			echo
			echo
			echo "======================================================================================="
			echo "== IOR MODE=$mode FILE_OPT=$file_opt RD_FCT=$rd_fct"
			time bash "$CWD/run-ior.sh" $mode $file_opt $rd_fct
		done
	done
done

for mode in easy hard ; do
	for rd_fct in {0..2} ; do
		echo
		echo
		echo "======================================================================================="
		echo "== MDTEST MODE=$mode RD_FCT=$rd_fct"
		time bash "$CWD/run-mdtest.sh" $mode $rd_fct
	done
done

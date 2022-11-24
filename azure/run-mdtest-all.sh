#!/bin/bash

# set -x
set -e -o pipefail

CWD="$(realpath "$(dirname $0)")"

source "$CWD/envs/env.sh"

od="$CWD/results/run-mdtest-all/$TIMESTAMP"
mkdir -p "$od"
of="$od/result.log"
> "$of"
for mdtest_mode in easy hard ; do
	for daos_rd_fac in 0 2 ; do
		for daos_dir_oclass in ${dir_oclasses[$daos_rd_fac]} ; do
			for daos_oclass in ${oclasses[$daos_rd_fac]} ; do
				echo
				echo "# ====================================================================================="
				echo "# mdtest_mode:$mdtest_mode daos_rd_fac:$daos_rd_fac daos_dir_oclass:$daos_dir_oclass daos_oclass:$daos_oclass"
				set +e +o pipefail
				time bash "$CWD/run-mdtest.sh" $od $mdtest_mode $daos_rd_fac $daos_dir_oclass $daos_oclass
				echo "return_code:$? mdtest_mode:$mdtest_mode daos_rd_fac:$daos_rd_fac daos_dir_oclass:$daos_dir_oclass daos_oclass:$daos_oclass" >> "$of"
				set -e -o pipefail
			done
		done
	done
done

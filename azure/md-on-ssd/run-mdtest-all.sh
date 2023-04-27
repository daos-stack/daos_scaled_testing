#!/bin/bash

# set -x
set -e -o pipefail

WD=$(dirname "$(realpath "$(dirname "$0")")")

source "$WD/envs/env.sh"

IOR_MODE=hard
IOR_SHARED=shared
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

bash "$WD/install-daos.sh" master-md_on_ssd

od="$WD/results/md_on_ssd/run-mdtest-all/$TIMESTAMP"
mkdir -p "$od"
of="$od/result.log"
> "$of"

for mdtest_mode in easy hard ; do
	for daos_redundancy in no_redundancy replication erasure_code ; do
		for daos_bdev_config in single_bdev multi_bdevs ; do
			daos_rd_fac=${DAOS_RD_FAC[$daos_redundancy]}
			daos_dir_oclass=${DAOS_DIR_OCLASS[$daos_redundancy]}
			daos_oclass=${DAOS_OCLASS[$daos_redundancy]}

			echo
			echo "# ====================================================================================="
			echo "# date:$(date "+%Y/%m/%d-%H:%M:%S") mdtest_mode:$mdtest_mode daos_rd_fac:$daos_rd_fac daos_dir_oclass:$daos_dir_oclass daos_oclass:$daos_oclass" daos_bdev_config:$daos_bdev_config

			set +e +o pipefail
			start_date=$(date "+%Y/%m/%d-%H:%M:%S")
			bash "$WD/run-mdtest.sh" "$od" $mdtest_mode $daos_rd_fac $daos_dir_oclass $daos_oclass $daos_bdev_config
			echo "start_date:$start_date end_date:$(date "+%Y/%m/%d-%H:%M:%S") return_code:$? mdtest_mode:$mdtest_mode daos_rd_fac:$daos_rd_fac daos_dir_oclass:$daos_dir_oclass daos_oclass:$daos_oclass daos_bdev_config:$daos_bdev_config" >> "$of"
			set -e -o pipefail
		done

	done
done

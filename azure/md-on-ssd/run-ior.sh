#!/bin/bash

# set -x
set -e -o pipefail

CWD="$(realpath "$(dirname $0)")"
CWD="$(dirname "$CWD")"

source "$CWD/envs/env.sh"

IOR_MODE=hard
IOR_SHARED=shared
DAOS_RD_FAC=0
DAOS_OCLASS=SX
DAOS_DIR_OCLASS=SX

mkdir -p "$CWD/results/md_on_ssd/ec_rotations"
bash "$CWD/install-daos.sh" master-ec_rotations
bash "$CWD/run-ior.sh" "$CWD/results/md_on_ssd/ec_rotations" $IOR_MODE $IOR_SHARED $DAOS_RD_FAC $DAOS_DIR_OCLASS $DAOS_OCLASS single_bdev

mkdir -p "$CWD/results/md_on_ssd/no_md_on_ssd"
bash "$CWD/install-daos.sh" master-no_md_on_ssd
bash "$CWD/run-ior.sh" "$CWD/results/md_on_ssd/no_md_on_ssd" $IOR_MODE $IOR_SHARED $DAOS_RD_FAC $DAOS_DIR_OCLASS $DAOS_OCLASS single_bdev

mkdir -p "$CWD/results/md_on_ssd/md_on_ssd"
bash "$CWD/install-daos.sh" master-md_on_ssd
bash "$CWD/run-ior.sh" "$CWD/results/md_on_ssd/md_on_ssd" $IOR_MODE $IOR_SHARED $DAOS_RD_FAC $DAOS_DIR_OCLASS $DAOS_OCLASS single_bdev
bash "$CWD/run-ior.sh" "$CWD/results/md_on_ssd/md_on_ssd" $IOR_MODE $IOR_SHARED $DAOS_RD_FAC $DAOS_DIR_OCLASS $DAOS_OCLASS multi_bdevs

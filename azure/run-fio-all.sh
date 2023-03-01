#!/bin/bash

# set -x
set -e -o pipefail

CWD="$(realpath "$(dirname $0)")"

source "$CWD/envs/env.sh"

LOG_DIR_ROOT="$CWD/results/run-fio/$TIMESTAMP"
mkdir -p "$LOG_DIR_ROOT"
DEBUG_FILE="$LOG_DIR_ROOT/debug.log"
> "$DEBUG_FILE"
RETURN_CODE_FILE="$LOG_DIR_ROOT/return_code.log"
> "$RETURN_CODE_FILE"

FIO_JOB_FILE="$CWD/files/dfs.fio"

# for FIO_MODE in easy hard ; do
for FIO_MODE in hard ; do
	for FIO_IODEPTH in 16 ; do
	# for FIO_IODEPTH in 1 8 16 32 64 ; do
		# for DAOS_RD_FAC in 0 2 ; do
		for DAOS_RD_FAC in 0 ; do
			# for DAOS_OCLASS in ${oclasses[$daos_rd_fac]} ; do
			for DAOS_OCLASS in SX ; do
				for DAOS_SERVERS_NB in 1 ; do
				# for DAOS_SERVERS_NB in 1 2 4 6 8 10 ; do
					# for DAOS_CLIENTS_NB in 1 2 4 8 16 ; do
					for DAOS_CLIENTS_NB in 1 2 4 6 8 ; do
						tee -a "$DEBUG_FILE" <<- EOF

						# ====================================================================================="
						# log_dir_root:$LOG_DIR_ROOT job_file:$FIO_JOB_FILE fio_mode:$FIO_MODE fio_iodepth:$FIO_IODEPTH daos_rd_fac:$DAOS_RD_FAC oclass:$DAOS_OCLASS servers_nb:$DAOS_SERVERS_NB clients_nb:$DAOS_CLIENTS_NB login_node:$LOGIN_NODE"
						EOF
						set +e +o pipefail
						time env LOG_DIR_ROOT=$LOG_DIR_ROOT FIO_JOB_FILE=$FIO_JOB_FILE FIO_MODE=$FIO_MODE FIO_IODEPTH=$FIO_IODEPTH DAOS_RD_FAC=$DAOS_RD_FAC DAOS_OCLASS=$DAOS_OCLASS DAOS_SERVERS_NB=$DAOS_SERVERS_NB DAOS_CLIENTS_NB=$DAOS_CLIENTS_NB DAOS_LOGIN_NODE=$LOGIN_NODE bash "$CWD/run-fio.sh" 2>&1 | tee -a "$DEBUG_FILE"
						tee -a "$RETURN_CODE_FILE" <<< "return_code:$? log_dir_root:$LOG_DIR_ROOT job_file:$FIO_JOB_FILE fio_mode:$FIO_MODE fio_iodepth:$FIO_IODEPTH daos_rd_fac:$DAOS_RD_FAC oclass:$DAOS_OCLASS servers_nb:$DAOS_SERVERS_NB clients_nb:$DAOS_CLIENTS_NB login_node:$LOGIN_NODE"
						set -e -o pipefail
					done
				done
			done
		done
	done
done

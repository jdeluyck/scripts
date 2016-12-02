#!/bin/bash

source borgbackup.conf

############################
# Functions...
############################
function check_prereqs {
	for BIN in "${@}"; do
		if [ ! -e "${BIN}" ]; then
			log error nomail "could not find ${BIN}, is it installed on your system?"
			exit 1
		fi
	done
}

function log_output {
	while IFS= read -r OUTPUT_LINE; do
		log info nomail "${OUTPUT_LINE}"
	done
}

function do_exec {
	STATE=${1}
	shift
	COMMAND="${*}"

	log info nomail "Executing ${COMMAND}"
	if [ ${STATE} = "quiet" ]; then
		${COMMAND} >/dev/null 2>&1
	else
		${COMMAND} 2>&1 | log_output
	fi

	return ${PIPESTATUS[0]}
}

function do_backup {
	BACKUP_PATH=${1}
	BACKUP_NAME=${2}
	COMPRESS=${3}

	do_exec verbose "${BORG_BIN} create -v --stats ${COMPRESS} ::${BACKUP_NAME}-{now:%Y-%m-%d} ${BACKUP_PATH}"

	if [ ${?} -ne 0 ]; then
		log error mail "borgbackup returned an error, repository ${BACKUP_NAME}!"
	else
		log info nomail "borgbackup completed successfully for ${BACKUP_NAME}"
	fi
}

function tolower {
	echo "${@}" | tr '[:upper:]' '[:lower:]'
}

function toupper {
	echo "${@}" | tr '[:lower:]' '[:upper:]'
}

function log {
	PRIO=$(tolower ${1})
	SENDMAIL=${2}
	shift 2
	TEXT="${*}"
	
	DATE=$(date '+%Y-%m-%d %H:%M')

	# Send mail?	
	if [ "${SENDMAIL}" = "mail" -a ${MAIL} -eq 1 ]; then
		echo "${TEXT}" | ${MAIL_BIN} -s "${MAIL_SUBJECT}" "${MAIL_TO}" -r "${MAIL_FROM}" 
	fi

	# Send to syslog?
	if [ ${SYSLOG} -eq 1 ]; then
		if [ "${TEMP}" = "error" ]; then
			TEMP="err"
		elif [ "${TEMP}" = "warning" ]; then
			TEMP="warn"
		else
			TEMP="${PRIO}"
		fi

		SYSLOG_PRIO="${SYSLOG_FACILITY}.${TEMP}"
		${SYSLOG_BIN} --id --tag ${SYSLOG_TAG} --priority ${SYSLOG_PRIO} -- "${TEXT}"
	fi

	# Send to text log?
	if [ ${LOG} -eq 1 ]; then
		PRIO=$(toupper ${PRIO})
		echo "[${DATE}] ${PRIO}: ${TEXT}" >> ${LOG_FILE}
	fi

	if [ ${STDOUT} -eq 1 ]; then
		PRIO=$(toupper ${PRIO})
                echo "[${DATE}] ${PRIO}: ${TEXT}" 
	fi
}

function do_init {
	do_exec quiet "${BORG_BIN} list"

	if [ ${?} -ne 0 ]; then
		log info nomail "${BORG_REPO} not initialised, initialising"
		
		do_exec quiet "${BORG_BIN} init -e keyfile >/dev/null 2>/dev/null"
		if ${?} -ne 0 ]; then
			log error mail "could not initialise ${BORG_REPO}, quitting!"
			exit 1
		else
			log info nomail "${BORG_REPO} initialised"
		fi
	fi
}

function do_prune {
	log info nomail "no prune yet"
}

function do_rclone {
	do_exec verbose "${RCLONE_BIN} sync ${BORG_REPO} ${RCLONE_REPO}"

	if [ ${?} -ne 0 ]; then
		log error mail "something went wrong running rclone sync!"
	else
		log info nomail "rclone sync completed successfully"
	fi

	if [ ${RCLONE_CLEANUP} -eq 1 ]; then
		do_exec verbose "${RCLONE_BIN} cleanup ${RCLONE_REPO}"

		if [ ${?} -ne 0 ]; then
			log error mail "something went wrong running rclone cleanup!"
		else
			log info nomail "rclone cleanup completed successfully"
		fi
	fi
}

###################### 
# Script starts here #
######################
# Check binaries
check_prereqs ${BORG_BIN} ${RCLONE_BIN} 

if [ ${MAIL} -eq 1 ]; then
	check_prereqs ${MAIL_BIN}
fi

if [ ${SYSLOG} -eq 1 ]; then
	check_prereqs ${SYSLOG_BIN}
fi

# Initialise borg repo if required
do_init

# Check if NFS-target is online
log info nomail "Checking if NFS target (${NFS_TARGET}) is online..."
ping ${NFS_TARGET} -c 1 -W 10 >/dev/null 2>/dev/null

if [ ${?} -eq 0 ]; then
	log info nomail "NFS target (${NFS_TARGET}) is online, proceeding with mounts and backups"

	for DIR in ${!NFS_MOUNTS[@]}; do 
		MOUNT="${NFS_MOUNT_DIR}/${DIR}"

		if [ ${NFS_MOUNTS[${DIR}]} == "yes" ]; then
			COMP="${BORG_COMPRESSION}"
		else
			COMP=""
		fi

		do_exec quiet mount ${MOUNT}
		if [ ${?} -ne 0 ]; then
			log error mail "could not mount ${MOUNT}, skipping backup"
			continue
		fi

		# Trigger borgbackup
		do_backup "${MOUNT}" "${DIR}" "${COMP}"

		do_exec quiet umount ${MOUNT}
		if [ ${?} -ne 0 ]; then
			log error mail "could not unmount ${MOUNT}"
		fi
	done
else
	log warning nomail "NFS target (${NFS_TARGET}) is offline, skipping NFS backup"
fi

##############################
# Normal backups

for DIR in ${!LOCAL_MOUNTS[@]}; do
	MOUNT="${LOCAL_MOUNT_DIR}/${DIR}"

	if [ ${LOCAL_MOUNTS[${DIR}]} == "yes" ]; then
		COMP="${BORG_COMPRESSION}"
	else
		COMP=""
	fi

	do_backup "${MOUNT}" "${DIR}" "${COMP}"
done

#################################
# rclone sync

do_rclone

############################
# Prune

do_prune


#!/bin/bash

# rclone_cron.sh

set -e

# Log directory
LOG_DIR="/config/log"

# Set RCLONE_CONFIG if not set
if [ -z "$RCLONE_CONFIG" ]; then
    RCLONE_CONFIG = "/config/rclone.conf"
fi

# Set RCLONE_CONFIG if not set
if [ -z "$CRON_COMMAND_FLAGS" ]; then
    CRON_COMMAND_FLAGS = " --create-empty-src-dirs --retries 5 --verbose --config ${RCLONE_CONFIG}"
fi

# Prepare the CRON_COMMAND
if [ -z "$CRON_COMMAND" ]; then
    CRON_COMMAND="rclone copy"
fi

# Loop to append remote and local paths to the CRON_COMMAND
for i in {1..20}; do
    remote_var="REMOTE_PATH_$i"
    local_var="LOCAL_PATH_$i"
    
    if [ ! -z "${!remote_var}" ] && [ ! -z "${!local_var}" ]; then
        echo "$(date -u +"%Y-%m-%d %H:%M:%S"): Cron running ${CRON_COMMAND} ${!local_var} ${!remote_var} ${CRON_COMMAND_FLAGS} --log-file $LOG_DIR/rclone.log --log-format date,time,UTC" >>  "$LOG_DIR/rclone.log"
        eval "${CRON_COMMAND} ${!local_var} ${!remote_var} ${CRON_COMMAND_FLAGS} --log-file $LOG_DIR/rclone.log --log-format date,time,UTC"
    fi
done

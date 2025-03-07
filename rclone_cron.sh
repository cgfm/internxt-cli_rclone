#!/bin/bash

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

# Check if the schedule key is provided as an argument
if [ $# -ne 1 ]; then
    echo "Usage: $0 <cron_schedule_key>"
    exit 1
fi

WORKING_YAML="/working/rclone_cron.yaml"
schedule_key="$1"

# Read the YAML file and execute commands for the specified schedule key
if [ -f "$WORKING_YAML" ]; then
    # Iterate over commands in the specified schedule
    yq e ".${schedule_key}[]" "$WORKING_YAML" | while IFS= read -r line; do
        # Extract command, command flags, local_path, and remote_path
        command=$(echo "$line" | yq e '.command // empty' -)
        command_flags=$(echo "$line" | yq e '.command_flags // empty' -)
        local_path=$(echo "$line" | yq e '.local_path // empty' -)
        remote_path=$(echo "$line" | yq e '.remote_path // empty' -)

        # Execute the command if all parts are set
        if [[ -n "$command" && -n "$local_path" && -n "$remote_path" ]]; then
            echo "$(date -u +"%Y-%m-%d %H:%M:%S"): Running command: $command $local_path $remote_path $command_flags" >> "$LOG_DIR/rclone.log"
            eval "$command $local_path $remote_path $command_flags --log-file=$LOG_DIR/rclone.log --log-format=date,time,UTC"
        elif [[ -n "$command" ]]; then
            echo "$(date -u +"%Y-%m-%d %H:%M:%S"): Running command: $command $command_flags" >> "$LOG_DIR/rclone.log"
            eval "$command $command_flags"
        fi
    done
else
    echo "Error: Configuration file $WORKING_YAML not found."
    exit 1
fi
